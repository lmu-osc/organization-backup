
# Restore all packages
try(renv::restore(prompt = FALSE))
try(renv::restore(project = "archiving_code", prompt = FALSE))
library(magrittr)

# remove back up files created more than 365 days ago

print(paste("Running remove_old_backups.R script on", Sys.time()))

old_backups <- list.files("archive") %>%
  purrr::keep(~ {
    as.Date(file.info(paste0("archive/", .x))$ctime) < (Sys.Date() - 365)
  })

print(paste("Old backups found: ", old_backups))


if (!length(old_backups)) {
  print("No old backups to remove")
} else {
  print("Removing old backups")
  purrr::walk(~ {
    print(paste0("Removing ", .x))
    file.remove(paste0("archive/", .x))
  })
}


