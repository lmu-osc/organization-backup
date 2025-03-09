
# Restore all packages
try(renv::restore(prompt = FALSE))
try(renv::restore(project = "archiving_code", prompt = FALSE))
library(magrittr)

# Add a check at the beginning that the GITHUB API is set


# get repo names
repos <- gh::gh(
  "/orgs/{org}/repos",
  org = "lmu-osc",
  type = "all",
  per_page = 100,
  .limit = Inf
) %>%
  purrr::map_chr("name") %>%
  purrr::set_names()


# get repo migrations
migration_urls <- purrr::map(repos, ~{
  gh::gh(
    "POST /orgs/{org}/migrations",
    org = "lmu-osc",
    repositories = list(.x)
  )
})



# create folders if needed
  # general archive folder
if (!dir.exists("archive")) {
  dir.create("archive")
}

  # monthly archive folder
current_ym <- format(Sys.Date(), "%Y-%m")
if (!dir.exists(paste0("archive/", current_ym))) {
  dir.create(paste0("archive/", current_ym))
}


# define get migration function
get_migration_state <- function(migration_url) {
  status <- gh::gh(migration_url)
  status$state
}



# read repo info into memory and save results
purrr::imap(migration_urls, ~{

  while (get_migration_state(migration_url = .x[["url"]]) != "exported") {
    print("Waiting for export to complete...")
    Sys.sleep(5)
  }

  handle <- curl::handle_setheaders(
    curl::new_handle(followlocation = FALSE),
    "Authorization" = paste("token", Sys.getenv("GITHUB_PAT")),
    "Accept" = "application/vnd.github.v3+json"
  )

  curl_url <- sprintf("%s/archive", .x[["url"]])

  # read into memory
  check <- curl::curl_fetch_memory(
    url = curl_url,
    handle = handle
  )

  parsed_headers <- curl::parse_headers_list(check$headers)

  curl::curl_download(
    url = parsed_headers$location,
    destfile = paste0("archive/", current_ym, "/", .y, ".tar.gz"),
  )

})





