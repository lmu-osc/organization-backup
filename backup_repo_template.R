
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



final_url <- sprintf("%s/archive", migration_ex[["url"]])


handle <- curl::handle_setheaders(
  curl::new_handle(followlocation = FALSE),
  "Authorization" = paste("token", Sys.getenv("GITHUB_LMU_OSC_PAT")),
  "Accept" = "application/vnd.github.v3+json"
)


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
