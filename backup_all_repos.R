print(paste("Running backup_all_repos.R script on", Sys.time()))

# Setup logging
log_file <- paste0("backup_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
log_msg <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] ", level, ": ", msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_msg("Starting backup_all_repos.R script")

# Activate the project library without trying to restore packages at runtime.
project_root <- "/archiving_code"
renv_activate <- file.path(project_root, "renv", "activate.R")
if (file.exists(renv_activate)) {
  source(renv_activate)
  log_msg(paste("Activated renv project:", project_root))
} else {
  log_msg(paste("renv activation file not found:", renv_activate), "WARN")
}

# Verify GitHub PAT
if (Sys.getenv("GITHUB_PAT") == "") {
  log_msg("GITHUB_PAT environment variable not set", "ERROR")
  stop("Please set the GITHUB_PAT environment variable.")
} else {
  log_msg("GITHUB_PAT environment variable is set")
}

# Retry wrapper for API calls
retry_api_call <- function(expr, max_attempts = 3, wait_time = 2) {
  for (attempt in 1:max_attempts) {
    result <- tryCatch({
      expr
    }, error = function(e) {
      if (attempt < max_attempts) {
        log_msg(paste("API call failed (attempt", attempt, "of", max_attempts, "), retrying in", wait_time, "seconds..."), "WARN")
        Sys.sleep(wait_time)
        NULL
      } else {
        log_msg(paste("API call failed after", max_attempts, "attempts:", e$message), "ERROR")
        stop(e)
      }
    })
    if (!is.null(result)) return(result)
  }
}

# Get repo names with retry
log_msg("Fetching repository list...")
repos_raw <- retry_api_call({
  gh::gh(
    "/orgs/{org}/repos",
    org = "lmu-osc",
    type = "all",
    per_page = 100,
    .limit = Inf
  )
}, max_attempts = 3)

repo_names <- vapply(repos_raw, function(repo) repo[["name"]], character(1))
repos <- stats::setNames(repo_names, repo_names)

log_msg(paste("Found", length(repos), "repositories to backup"))

# Get repo migrations with error handling
log_msg("Initiating migrations...")
migration_rows <- lapply(seq_along(repos), function(i) {
  repo_name <- names(repos)[i]
  tryCatch({
    url_result <- retry_api_call({
      gh::gh(
        "POST /orgs/{org}/migrations",
        org = "lmu-osc",
        repositories = list(repos[[i]])
      )
    }, max_attempts = 3)

    data.frame(
      repo = repo_name,
      url = url_result[["url"]],
      state = "pending",
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    log_msg(paste("Failed to initiate migration for", repo_name, ":", e$message), "ERROR")
    data.frame(
      repo = repo_name,
      url = NA,
      state = "failed",
      stringsAsFactors = FALSE
    )
  })
})

migration_urls <- do.call(rbind, migration_rows)

current_ymd <- format(Sys.Date(), "%Y-%m-%d")
archive_dir <- file.path("/archive", current_ymd)
if (!dir.exists(archive_dir)) {
  dir.create(archive_dir, recursive = TRUE)
  log_msg(paste("Created archive folder:", archive_dir))
}

# Enhanced migration state checker with timeout
get_migration_state <- function(migration_url, max_wait_seconds = 3600) {
  log_msg(paste("Checking migration status:", migration_url))
  start_time <- Sys.time()
  check_interval <- 5
  max_retries <- 3
  
  while (TRUE) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    
    if (elapsed > max_wait_seconds) {
      log_msg(paste("Migration timeout after", elapsed, "seconds"), "ERROR")
      return("timeout")
    }
    
    result <- tryCatch({
      retry_api_call({
        gh::gh(migration_url)
      }, max_attempts = max_retries)
    }, error = function(e) {
      log_msg(paste("Failed to check migration status:", e$message), "WARN")
      NULL
    })
    
    if (!is.null(result) && !is.null(result$state)) {
      state <- result$state
      log_msg(paste("Migration state:", state, "(elapsed:", round(elapsed), "seconds)"))
      
      if (state %in% c("exported", "failed")) {
        return(state)
      }
      
      if (state != "exported") {
        Sys.sleep(check_interval)
      }
    } else {
      Sys.sleep(check_interval)
    }
  }
}

# Download results with error handling
results_rows <- lapply(seq_len(nrow(migration_urls)), function(i) {
  repo <- migration_urls$repo[i]
  migration_url <- migration_urls$url[i]
  initial_state <- migration_urls$state[i]

  tryCatch({
    log_msg(paste("Processing repository:", repo))
    
    if (is.na(migration_url) || initial_state == "failed") {
      log_msg(paste("Skipping", repo, "due to failed migration initiation"), "WARN")
      return(data.frame(
        repo = repo,
        status = "skipped",
        reason = "failed_initiation",
        timestamp = Sys.time(),
        stringsAsFactors = FALSE
      ))
    }
    
    tryCatch({
      # Wait for migration to complete with timeout
      migration_state <- get_migration_state(migration_url, max_wait_seconds = 3600)
      
      if (migration_state == "timeout") {
        log_msg(paste("Migration for", repo, "timed out"), "ERROR")
        return(data.frame(
          repo = repo,
          status = "timeout",
          reason = "export_timeout",
          timestamp = Sys.time(),
          stringsAsFactors = FALSE
        ))
      }
      
      if (migration_state != "exported") {
        log_msg(paste("Migration for", repo, "failed with state:", migration_state), "ERROR")
        return(data.frame(
          repo = repo,
          status = "failed",
          reason = paste("export_state:", migration_state),
          timestamp = Sys.time(),
          stringsAsFactors = FALSE
        ))
      }
      
      # Download migration archive
      handle <- curl::handle_setheaders(
        curl::new_handle(followlocation = FALSE),
        "Authorization" = paste("token", Sys.getenv("GITHUB_PAT")),
        "Accept" = "application/vnd.github.v3+json"
      )
      
      curl_url <- sprintf("%s/archive", migration_url)
      
      # Fetch with timeout
      check <- tryCatch({
        curl::curl_fetch_memory(url = curl_url, handle = handle)
      }, error = function(e) {
        log_msg(paste("Failed to fetch archive for", repo, ":", e$message), "ERROR")
        NULL
      })
      
      if (is.null(check)) {
        return(data.frame(
          repo = repo,
          status = "failed",
          reason = "archive_fetch_failed",
          timestamp = Sys.time(),
          stringsAsFactors = FALSE
        ))
      }
      
      parsed_headers <- curl::parse_headers_list(check$headers)
      
      if (is.null(parsed_headers$location)) {
        log_msg(paste("No download URL found for", repo), "WARN")
        return(data.frame(
          repo = repo,
          status = "failed",
          reason = "no_download_url",
          timestamp = Sys.time(),
          stringsAsFactors = FALSE
        ))
      }
      
      # Download file
      destfile <- paste0(archive_dir, "/", repo, ".tar.gz")
      download_result <- tryCatch({
        curl::curl_download(
          url = parsed_headers$location,
          destfile = destfile
        )
        "success"
      }, error = function(e) {
        log_msg(paste("Failed to download archive for", repo, ":", e$message), "ERROR")
        "failed"
      })
      
      if (download_result == "success") {
        file_size <- file.size(destfile)
        log_msg(paste("Successfully downloaded", repo, "to", destfile, "(", file_size, "bytes)"))
        
        data.frame(
          repo = repo,
          status = "success",
          reason = NA,
          timestamp = Sys.time(),
          stringsAsFactors = FALSE
        )
      } else {
        return(data.frame(
          repo = repo,
          status = "failed",
          reason = "download_failed",
          timestamp = Sys.time(),
          stringsAsFactors = FALSE
        ))
      }
      
    }, error = function(e) {
      log_msg(paste("Unexpected error processing", repo, ":", e$message), "ERROR")
      data.frame(
        repo = repo,
        status = "error",
        reason = e$message,
        timestamp = Sys.time(),
        stringsAsFactors = FALSE
      )
    })
  }, error = function(e) {
    log_msg(paste("Unexpected error processing", repo, ":", e$message), "ERROR")
    data.frame(
      repo = repo,
      status = "error",
      reason = e$message,
      timestamp = Sys.time(),
      stringsAsFactors = FALSE
    )
  })
})

results_summary <- do.call(rbind, results_rows)

# Summary report
log_msg("=== BACKUP SUMMARY ===")
success_count <- sum(results_summary$status == "success")
failed_count <- sum(results_summary$status %in% c("failed", "error"))
timeout_count <- sum(results_summary$status == "timeout")
skipped_count <- sum(results_summary$status == "skipped")

log_msg(paste("Successful:", success_count))
log_msg(paste("Failed:", failed_count))
log_msg(paste("Timed out:", timeout_count))
log_msg(paste("Skipped:", skipped_count))

if (failed_count > 0 || timeout_count > 0) {
  log_msg("Failed/timed out repositories:", "WARN")
  failed_repos <- results_summary[results_summary$status %in% c("failed", "timeout"), ]
  for (i in seq_len(nrow(failed_repos))) {
    log_msg(paste("-", failed_repos$repo[i], ":", failed_repos$reason[i]), "WARN")
  }
}

# Save results to CSV
results_file <- paste0(archive_dir, "/backup_results_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
write.csv(results_summary, file = results_file, row.names = FALSE)
log_msg(paste("Results saved to:", results_file))

log_msg("Backup completed")
