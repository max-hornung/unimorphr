#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/unimorphr}"
SHINY_PORT="${SHINY_PORT:-3838}"

export RENV_CONFIG_AUTOLOADER_ENABLED=false

cd "$APP_DIR"

echo ""
echo "Rebuilding local UniMorph database."
echo "This may take a while."
echo ""

rm -f data/unimorph/unimorph.duckdb
rm -f data/unimorph/unimorph.duckdb.wal

Rscript --vanilla -e 'source("R/setup_local_database.R")'

echo ""
echo "Starting Shiny app."
echo "Keep this terminal window open while the app is running."
echo ""

Rscript --vanilla -e '
  port <- as.integer(Sys.getenv("SHINY_PORT", "3838"))

  shiny::runApp(
    appDir = ".",
    host = "127.0.0.1",
    port = port,
    launch.browser = function(url) {
      message("Opening app at: ", url)
      utils::browseURL(url)
    }
  )
'
