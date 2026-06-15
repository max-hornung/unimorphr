if (!requireNamespace("shiny", quietly = TRUE)) {
  install.packages("shiny")
}

if (!requireNamespace("DBI", quietly = TRUE)) {
  install.packages("DBI")
}

if (!requireNamespace("duckdb", quietly = TRUE)) {
  install.packages("duckdb")
}

source("R/unimorph_backend.R")

if (!database_exists()) {
  message("Local database not found. Building it now.")
  source("R/setup_local_database.R")
}

shiny::runApp()
