library(dplyr)
library(readxl)
# continue here!

# Read it into R
les_lemma <- read_xlsx("~/proj/iris/data/raw/googledrive/LES_LEMMA.xlsx") |>
  rename(
    language = Language,
    lemma = Lemma
  ) |>
  select(1:7) |>
  mutate(
    lemma = tolower(lemma)
  )

# Load your UniMorph backend
source("R/unimorph_backend.R")

# Read language config: lang,label
language_config <- read_language_config() %>%
  rename(
    iso_code = lang,
    language = label
  )

# Add ISO code to your lemma data
query_unimorph_long <- function(row_id, language_name, iso_code, lemma) {

  forms <- get_forms(
    lang = iso_code,
    lemma = lemma
  )

  # If UniMorph finds no forms, keep one row with NA form
  if (nrow(forms) == 0) {
    return(data.frame(
      row_id = row_id,
      Language = language_name,
      iso_code = iso_code,
      lemma = lemma,
      word_form = NA_character_,
      unimorph_status = "not_found",
      stringsAsFactors = FALSE
    ))
  }

  # One row per unique word form
  forms %>%
    distinct(form) %>%
    rename(word_form = form) %>%
    mutate(
      row_id = row_id,
      Language = language_name,
      iso_code = iso_code,
      lemma = lemma,
      unimorph_status = "found"
    ) %>%
    select(
      row_id,
      Language,
      iso_code,
      lemma,
      word_form,
      unimorph_status
    )
}

# Loop over all rows
results_list <- lapply(seq_len(nrow(les_lemma_lookup)), function(i) {
  query_unimorph_long(
    row_id = les_lemma_lookup$row_id[i],
    language_name = les_lemma_lookup$language[i],
    iso_code = les_lemma_lookup$iso_code[i],
    lemma = les_lemma_lookup$lemma[i]
  )
})

# Combine into one long dataframe
unimorph_results_long <- bind_rows(results_list)

# Optional: join back original columns from your Excel file
unimorph_results_long <- les_lemma_lookup %>%
  select(row_id, everything()) %>%
  left_join(
    unimorph_results_long,
    by = c("row_id", "iso_code", "lemma")
  )

# Save locally
dir.create("~/proj/iris/data/processed", recursive = TRUE, showWarnings = FALSE)

write_csv(
  unimorph_results_long,
  "~/proj/iris/data/processed/LES_LEMMA_unimorph_forms_long.csv"
)
