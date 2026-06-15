#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/max-hornung/unimorphr.git"
APP_DIR="${APP_DIR:-$HOME/unimorphr}"
SHINY_PORT="${SHINY_PORT:-3838}"

echo ""
echo "UniMorph Shiny app installer and launcher"
echo "========================================"
echo ""

install_system_dependencies() {
  if command -v git >/dev/null 2>&1 && command -v Rscript >/dev/null 2>&1; then
    echo "Git and R are already installed."
    return
  fi

  echo "Some system dependencies are missing."
  echo "The script will try to install Git and R."
  echo ""

  OS="$(uname -s)"

  if [ "$OS" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      echo "Homebrew is not installed. Installing Homebrew first."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi

    brew install git r

  elif [ "$OS" = "Linux" ]; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y \
        git \
        r-base \
        r-base-dev \
        build-essential \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev

    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y \
        git \
        R \
        R-devel \
        gcc \
        gcc-c++ \
        make \
        libcurl-devel \
        openssl-devel \
        libxml2-devel

    else
      echo "Could not detect a supported Linux package manager."
      echo "Please install Git and R manually, then run this command again."
      exit 1
    fi

  else
    echo "Unsupported operating system: $OS"
    echo "Please install Git and R manually, then run this command again."
    exit 1
  fi
}

check_required_commands() {
  if ! command -v git >/dev/null 2>&1; then
    echo "Git is still not available."
    exit 1
  fi

  if ! command -v Rscript >/dev/null 2>&1; then
    echo "Rscript is still not available."
    exit 1
  fi
}

clone_or_update_repo() {
  if [ -d "$APP_DIR/.git" ]; then
    echo ""
    echo "Updating existing app folder:"
    echo "$APP_DIR"
    git -C "$APP_DIR" pull --ff-only
  else
    echo ""
    echo "Cloning app into:"
    echo "$APP_DIR"
    git clone "$REPO_URL" "$APP_DIR"
  fi

  cd "$APP_DIR"
}

ensure_language_file_exists() {
  if [ ! -f "config/languages.csv" ]; then
    echo "config/languages.csv not found. Creating a minimal language file."
    mkdir -p config
    printf "lang,label\neng,English\ndeu,German\nfra,French\n" > config/languages.csv
  fi
}

show_languages() {
  ensure_language_file_exists

  echo ""
  echo "Current languages in config/languages.csv:"
  echo "------------------------------------------"

  awk -F',' '
    NR == 1 { next }
    NF >= 2 { printf "  %s - %s\n", $1, $2 }
  ' config/languages.csv

  echo ""
}

add_languages_interactively() {
  LANGUAGES_CHANGED=0

  read -r -p "Do you want to add another language before building the database? [y/N] " ANSWER

  case "$ANSWER" in
    y|Y|yes|YES)
      echo ""
      echo "You can now add languages interactively."
      echo "Use UniMorph language codes such as:"
      echo "  eng = English"
      echo "  deu = German"
      echo "  fra = French"
      echo "  swe = Swedish"
      echo "  spa = Spanish"
      echo ""
      ;;

    *)
      echo "No extra languages added."
      echo ""
      return
      ;;
  esac

  while true; do
    echo ""
    read -r -p "Language code, for example swe. Press Enter to stop: " LANG_CODE

    if [ -z "$LANG_CODE" ]; then
      break
    fi

    LANG_CODE="$(printf "%s" "$LANG_CODE" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    if ! printf "%s" "$LANG_CODE" | grep -Eq '^[a-z0-9_-]+$'; then
      echo "Invalid language code: $LANG_CODE"
      echo "Please use codes such as eng, deu, fra, swe, spa."
      continue
    fi

    if grep -qE "^${LANG_CODE}," config/languages.csv; then
      echo "Language already exists: $LANG_CODE"
      continue
    fi

    read -r -p "Language label, for example Swedish: " LANG_LABEL

    LANG_LABEL="$(printf "%s" "$LANG_LABEL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    if [ -z "$LANG_LABEL" ]; then
      LANG_LABEL="$LANG_CODE"
    fi

    printf "%s,%s\n" "$LANG_CODE" "$LANG_LABEL" >> config/languages.csv

    echo "Added: $LANG_CODE - $LANG_LABEL"
    LANGUAGES_CHANGED=1

    read -r -p "Add another language? [y/N] " MORE

    case "$MORE" in
      y|Y|yes|YES)
        continue
        ;;
      *)
        break
        ;;
    esac
  done

  echo ""
  echo "Final language list:"
  echo "--------------------"

  awk -F',' '
    NR == 1 { next }
    NF >= 2 { printf "  %s - %s\n", $1, $2 }
  ' config/languages.csv

  echo ""
}

install_r_packages() {
  echo "Installing required R packages if needed..."

  Rscript -e '
    options(repos = c(CRAN = "https://cloud.r-project.org"))

    pkgs <- c("shiny", "DBI", "duckdb")
    missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]

    if (length(missing) > 0) {
      message("Installing: ", paste(missing, collapse = ", "))
      install.packages(missing)
    } else {
      message("All required R packages are already installed.")
    }
  '
}

build_database_if_needed() {
  DB_FILE="data/unimorph/unimorph.duckdb"

  if [ "${LANGUAGES_CHANGED:-0}" = "1" ]; then
    echo "Languages changed. Rebuilding database."
    rm -f data/unimorph/unimorph.duckdb
    rm -f data/unimorph/unimorph.duckdb.wal
  fi

  if [ ! -f "$DB_FILE" ]; then
    echo ""
    echo "Building local UniMorph database."
    echo "This may take a while on first run."
    Rscript -e 'source("R/setup_local_database.R")'
  else
    echo "Local database already exists."
  fi
}

launch_app() {
  echo ""
  echo "Starting Shiny app."
  echo "The terminal must stay open while the app is running."
  echo ""

  Rscript -e '
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
}

install_system_dependencies
check_required_commands
clone_or_update_repo
show_languages
add_languages_interactively
install_r_packages
build_database_if_needed
launch_app
