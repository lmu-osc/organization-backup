repos <- gh::gh(
  "/orgs/{org}/repos",
  org = "lmu-osc",
  type = "all",
  per_page = 100,
  .limit = Inf
) |>
  purrr::map_chr("name")


migration_ex <- gh::gh(
  "POST /orgs/{org}/migrations",
  org = "lmu-osc",
  repositories = as.list("introduction-to-renv")
)



get_migration_state <- function(migration_url) {
  status <- gh::gh(migration_url)
  status$state
}

while (get_migration_state(migration_url = migration_ex[["url"]]) != "exported") {
  print("Waiting for export to complete...")
  Sys.sleep(60)
}





handle <- curl::handle_setheaders(
  curl::new_handle(followlocation = FALSE),
  "Authorization" = paste("token", Sys.getenv("GITHUB_PAT")),
  "Accept" = "application/vnd.github.v3+json"
)







final_url <- sprintf("%s/archive", migration_ex[["url"]])


check <- curl::curl_fetch_memory(
  url = final_url,
  handle = handle
)


parsed_headers <- curl::parse_headers_list(check$headers)

parsed_headers$location

curl::curl_download(
  url = parsed_headers$location,
  destfile = "introduction-to-renv-archive.zip"
)
