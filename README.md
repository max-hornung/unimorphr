# UniMorphR: Local UniMorph Lemma Lookup

This repository provides a simple local R/Shiny interface for looking up inflected word forms from [UniMorph](https://unimorph.github.io/).

The tool lets you enter a **language** and a **lemma**, then returns the known UniMorph word forms and morphological feature bundles for that lemma.

For example:

| Language | Lemma   |
| -------- | ------- |
| German   | `gehen` |
| English  | `go`    |
| French   | `aller` |

The app builds a local DuckDB database on your own computer. The UniMorph data and the database are **not stored in this GitHub repository**.

---

## What this tool does

This tool retrieves forms from UniMorph using the structure:

```text
language + lemma -> inflected forms
```

Example output:

```text
lang | lemma | form  | features
deu  | gehen | gehe  | V;IND;PRS;1;SG
deu  | gehen | gehst | V;IND;PRS;2;SG
deu  | gehen | geht  | V;IND;PRS;3;SG
```

Important: the tool retrieves forms that are available in UniMorph. It does not generate missing forms. If a lemma is not present in UniMorph for a given language, the result will be empty.

---

## Who can use this repository?

Anyone can clone or fork this repository.

However, only the repository owner can directly change the original repository. If you want to adapt the tool, please fork the repository and make changes in your own copy.

---

## Requirements

Please install the following before using the tool:

1. R
2. RStudio
3. An internet connection for the first-time database setup

No external database server is required. DuckDB runs locally on your computer.

---

## First-time setup

### 1. Clone or download the repository

Clone the repository from GitHub, or download it as a ZIP file.

Then open the RStudio project file:

```text
unimorphr.Rproj
```

in RStudio.

---

### 2. Restore the R package environment

In the RStudio Console, run:

```r
install.packages("renv")
renv::restore()
```

This installs the R packages needed by the project.

---

### 3. Build the local UniMorph database

Run:

```r
source("R/setup_local_database.R")
```

This will:

1. Read the list of languages from `config/languages.csv`
2. Download the corresponding UniMorph files
3. Build a local DuckDB database on your computer

The downloaded data will be stored locally in:

```text
data/unimorph/raw/
```

The local database will be stored in:

```text
data/unimorph/unimorph.duckdb
```

These files are not uploaded to GitHub.

---

### 4. Start the app

Run:

```r
shiny::runApp()
```

Alternatively, run:

```r
source("run_app.R")
```

The app should open in RStudio or in your web browser.

---

## Later use

After the first setup, you usually only need to run:

```r
source("run_app.R")
```

If the database already exists, the app starts directly.

If the database is missing, `run_app.R` will build it first.

---

## How to use the app

1. Select a language.
2. Enter a lemma.
3. Click **Search**.
4. Inspect the returned forms.
5. Download the results as a CSV file if needed.

Example searches:

| Language | Lemma   |
| -------- | ------- |
| German   | `gehen` |
| English  | `go`    |
| French   | `aller` |

---

## Adding more languages

The list of languages is stored in:

```text
config/languages.csv
```

The file has two columns:

```csv
lang,label
eng,English
deu,German
fra,French
```

To add a language, add a new row. For example:

```csv
swe,Swedish
spa,Spanish
ita,Italian
nld,Dutch
```

After changing `config/languages.csv`, rebuild the database:

```r
source("R/setup_local_database.R")
```

---

## Project structure

```text
unimorphr/
  app.R
  run_app.R
  README.md
  renv.lock

  R/
    unimorph_backend.R
    setup_local_database.R

  config/
    languages.csv

  data/
    unimorph/
      raw/
      unimorph.duckdb

  output/
```

The important files are:

| File                       | Purpose                                                |
| -------------------------- | ------------------------------------------------------ |
| `app.R`                    | Shiny app interface                                    |
| `run_app.R`                | Easy launcher for the app                              |
| `R/unimorph_backend.R`     | Core functions for downloading, building, and querying |
| `R/setup_local_database.R` | Builds the local database                              |
| `config/languages.csv`     | List of languages to include                           |
| `renv.lock`                | Records R package versions                             |

---

## What is stored locally?

The UniMorph data and DuckDB database are created on your own computer.

They are not included in the GitHub repository.

Locally generated files include:

```text
data/unimorph/raw/
data/unimorph/unimorph.duckdb
output/
```

These files can be deleted and rebuilt at any time by running:

```r
source("R/setup_local_database.R")
```

---

## Troubleshooting

### The app says the database is missing

Run:

```r
source("R/setup_local_database.R")
```

Then start the app again:

```r
shiny::runApp()
```

---

### A language is missing

Check whether the language is listed in:

```text
config/languages.csv
```

Then rebuild the database:

```r
source("R/setup_local_database.R")
```

---

### A lemma returns no forms

This usually means that the lemma is not available in UniMorph for that language, or that the spelling does not match the UniMorph lemma.

Try checking:

1. Whether the language code is correct
2. Whether the lemma spelling is correct
3. Whether the lemma exists in the UniMorph data for that language

---

### Package installation problems

Try running:

```r
renv::restore()
```

If problems remain, restart RStudio and run:

```r
install.packages("renv")
renv::restore()
```

---

## Suggested workflow for contributors

If you want to modify the tool:

1. Fork this repository.
2. Make changes in your fork.
3. Test locally.
4. Submit a pull request if you want to suggest changes to the original repository.

Please do not expect direct write access to the original repository.

---

## License

Please check the licenses of both this repository and the underlying UniMorph data before redistributing derived data.

---

## Citation

If you use this tool in academic work, please cite UniMorph and any relevant language-specific UniMorph resources.
