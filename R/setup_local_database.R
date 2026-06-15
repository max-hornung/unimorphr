source("R/unimorph_backend.R")

languages <- read_language_config()

message("Building local UniMorph database.")
message("Languages: ", paste(languages$lang, collapse = ", "))

build_unimorph_db(languages$lang)

message("Done.")
message("Database created at: ", unimorph_db_path())
