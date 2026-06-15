library(DBI)
library(duckdb)

unimorph_raw_dir <- function() {
  file.path("data", "unimorph", "raw")
}

unimorph_db_path <- function() {
  file.path("data", "unimorph", "unimorph.duckdb")
}

make_dirs <- function() {
  dir.create(file.path("data", "unimorph", "raw"), recursive = TRUE, showWarnings = FALSE)
  dir.create("output", recursive = TRUE, showWarnings = FALSE)
}

read_language_config <- function(path = file.path("config", "languages.csv")) {
  if (!file.exists(path)) {
    stop("Missing language configuration file: ", path)
  }

  x <- read.csv(path, stringsAsFactors = FALSE)

  if (!all(c("lang", "label") %in% names(x))) {
    stop("config/languages.csv must contain columns: lang and label")
  }

  x
}

unimorph_url_candidates <- function(lang) {
  c(
    paste0("https://raw.githubusercontent.com/unimorph/", lang, "/master/", lang),
    paste0("https://raw.githubusercontent.com/unimorph/", lang, "/main/", lang)
  )
}

download_unimorph_lang <- function(lang, overwrite = FALSE) {
  make_dirs()

  out_path <- file.path(unimorph_raw_dir(), paste0(lang, ".tsv"))

  if (file.exists(out_path) && !overwrite) {
    message("Already downloaded: ", lang)
    return(out_path)
  }

  urls <- unimorph_url_candidates(lang)
  tmp <- tempfile(fileext = ".tsv")

  for (url in urls) {
    message("Trying: ", url)

    ok <- tryCatch(
      {
        utils::download.file(
          url = url,
          destfile = tmp,
          quiet = TRUE,
          mode = "wb"
        )
        TRUE
      },
      warning = function(w) FALSE,
      error = function(e) FALSE
    )

    if (ok && file.exists(tmp) && file.info(tmp)$size > 0) {
      first_lines <- readLines(tmp, n = 5, warn = FALSE, encoding = "UTF-8")

      if (any(grepl("\t", first_lines, fixed = TRUE))) {
        file.copy(tmp, out_path, overwrite = TRUE)
        message("Downloaded: ", lang)
        return(out_path)
      }
    }
  }

  stop("Could not download UniMorph data for language code: ", lang)
}

read_unimorph_lang <- function(lang) {
  path <- file.path(unimorph_raw_dir(), paste0(lang, ".tsv"))

  if (!file.exists(path)) {
    stop("Missing UniMorph file for language: ", lang)
  }

  x <- utils::read.delim(
    file = path,
    header = FALSE,
    sep = "\t",
    quote = "",
    stringsAsFactors = FALSE,
    col.names = c("lemma", "form", "features"),
    fileEncoding = "UTF-8"
  )

  x$lang <- lang
  x <- x[, c("lang", "lemma", "form", "features")]
  x <- x[!is.na(x$lemma) & !is.na(x$form) & !is.na(x$features), ]

  rownames(x) <- NULL
  x
}

build_unimorph_db <- function(langs, overwrite_downloads = FALSE) {
  make_dirs()

  for (lang in langs) {
    download_unimorph_lang(lang, overwrite = overwrite_downloads)
  }

  db_path <- unimorph_db_path()

  if (file.exists(db_path)) {
    file.remove(db_path)
  }

  wal_path <- paste0(db_path, ".wal")

  if (file.exists(wal_path)) {
    file.remove(wal_path)
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbExecute(
    con,
    "
    CREATE TABLE forms (
      lang VARCHAR,
      lemma VARCHAR,
      form VARCHAR,
      features VARCHAR
    )
    "
  )

  for (lang in langs) {
    message("Importing into database: ", lang)

    x <- read_unimorph_lang(lang)

    DBI::dbWriteTable(
      con,
      "forms",
      x,
      append = TRUE
    )
  }

  DBI::dbExecute(
    con,
    "
    CREATE INDEX idx_forms_lang_lemma
    ON forms(lang, lemma)
    "
  )

  invisible(db_path)
}

database_exists <- function() {
  file.exists(unimorph_db_path())
}

get_forms <- function(lang, lemma) {
  if (!database_exists()) {
    stop("Database not found. Run source('R/setup_local_database.R') first.")
  }

  con <- DBI::dbConnect(
    duckdb::duckdb(),
    dbdir = unimorph_db_path(),
    read_only = TRUE
  )

  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbGetQuery(
    con,
    "
    SELECT lang, lemma, form, features
    FROM forms
    WHERE lang = ?
      AND lemma = ?
    ORDER BY features, form
    ",
    params = list(lang, lemma)
  )
}

available_languages <- function() {
  if (!database_exists()) {
    return(character())
  }

  con <- DBI::dbConnect(
    duckdb::duckdb(),
    dbdir = unimorph_db_path(),
    read_only = TRUE
  )

  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  out <- DBI::dbGetQuery(
    con,
    "
    SELECT DISTINCT lang
    FROM forms
    ORDER BY lang
    "
  )

  out$lang
}
