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

## Installation and start

You do **not** need RStudio to use the app.

To install and start the app, paste this command into your terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/max-hornung/unimorphr/main/install_and_run.sh)"
```


The script will:

1. check whether Git and R are installed;
2. clone or update this repository;
3. show the currently available languages;
4. ask whether you want to add more languages;
5. install the required R packages;
6. build the local UniMorph DuckDB database;
7. start the Shiny app in your browser.

The first run may take a few minutes because R packages and UniMorph data need to be downloaded.

Keep the terminal window open while the app is running.

If the browser does not open automatically, go to:

```text
http://127.0.0.1:3838
```

You will find the cloned unimorphr repo in your home directory

## Later use

To start the app again later, run the same terminal command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/max-hornung/unimorphr/main/install_and_run.sh)"
```

The script will update the repository if needed and then start the app.

## Adding languages during setup

During setup, the script shows the languages currently listed in:

```text
config/languages.csv
```

It then asks whether you want to add more languages.

If you answer `y`, enter one language at a time, for example:

```text
swe,Swedish
spa,Spanish
ita,Italian
```

Press Enter on an empty line when you are done.

The database will then be built using the updated language list.

---

## How to use the app

1. Select a language.
2. Enter a lemma and see drop-down recommendations.
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
config/languages.local.csv
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

After changing `config/languages.local.csv`, rebuild the database:

```r
source("R/setup_local_database.R")
```

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
config/languages.local.csv
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

## License

Please check the licenses of both this repository and the underlying UniMorph data before redistributing derived data.

---

## Citation

If you use this tool in academic work, please cite UniMorph and any relevant language-specific UniMorph resources.
