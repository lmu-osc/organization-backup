

# remove back up files created more than 365 days ago

list.files("archive") %>%
  purrr::keep(~ {
    as.Date(file.info(paste0("archive/", .x))$ctime) < (Sys.Date() - 365)
  }) %>%
  purrr::walk(~ {
    file.remove(paste0("archive/", .x))
  })

