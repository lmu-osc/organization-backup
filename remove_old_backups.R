
# Restore all packages
try(renv::restore(prompt = FALSE))
try(renv::restore(project = "archiving_code", prompt = FALSE))
library(magrittr)

# remove back up files created more than 365 days ago

print(paste("Running remove_old_backups.R script on", Sys.time()))

all_backups <- list.files("archive")

old_backups <- all_backups %>%
  purrr::keep(~ {
    as.Date(file.info(paste0("archive/", .x))$ctime) < (Sys.Date() - 365)
  })

print(paste("Old backups found: ", old_backups))


# emergency_backups

latest_backup_date <- as.Date(min(file.info(paste0("archive/", all_backups))$ctime))

if (latest_backup_date < (Sys.Date() - 180)) {
  print("Warning! The latest backup is more than 180 days old. Please check the backups and whether the GITHUB PAT has expired. The script will not remove any backups.")
  emergency_backups <- old_backups
} else {
  emergency_backups <- ""
}


backups_to_remove <- old_backups %>%
  setdiff(emergency_backups)



if (!length(backups_to_remove)) {
  print("No backups to remove")
} else {
  print("Removing old backups")
  purrr::walk(~ {
    print(paste0("Removing ", .x))
    file.remove(paste0("archive/", .x))
  })
}


