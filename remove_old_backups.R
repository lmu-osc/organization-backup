
# Restore all packages
try(renv::restore(prompt = FALSE))
try(renv::restore(project = "archiving_code", prompt = FALSE))
library(magrittr)


max_backup_life_days <- 365*1.5
max_days_before_notify_backup_failure <- 75

latest_backup_date <- as.Date(min(file.info(paste0("/archive/", all_backups))$ctime))
all_backups <- list.files("archive")

print(paste("The latest backup date was on", latest_backup_date))
print(paste("Running remove_old_backups.R script on", Sys.time()))


if (latest_backup_date <= (Sys.Date() - max_days_before_notify_backup_failure)) {
  stop("The latest backup is more than 14 days old. Please check the backups and whether the GITHUB PAT has expired. Backup removal script has not been completed.")
}



old_backups <- all_backups %>%
  purrr::keep(~ {
    as.Date(file.info(paste0("/archive/", .x))$ctime) < (Sys.Date() - max_backup_life_days)
  })

print(paste("Old backups found: ", old_backups))

if (!length(old_backups)) {
  print("No backups to remove")
} else {
  print("Removing old backups")
  purrr::walk(old_backups, ~ {
    print(paste0("Removing ", .x))
    file.remove(paste0("/archive/", .x))
  })
}




