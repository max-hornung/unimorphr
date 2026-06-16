#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/max-hornung/unimorphr.git"
APP_DIR="${APP_DIR:-$HOME/unimorph-lemma-lookup}"
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

    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y \
        git \
        R \
        R-devel \
        gcc \
        gcc-c++ \
        make \
        libcurl-devel \
        openssl-devel \
        libxml2-devel

    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy --noconfirm \
        git \
        r \
        base-devel \
        curl \
        openssl \
        libxml2

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
    echo "Please install Git manually, then run this command again."
    exit 1
  fi

  if ! command -v Rscript >/dev/null 2>&1; then
    echo "Rscript is still not available."
    echo "Please install R manually, then run this command again."
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

show_languages() {
  echo ""
  echo "Current languages in config/languages.csv:"
  echo "------------------------------------------"

  if [ ! -f "config/languages.csv" ]; then
    echo "config/languages.csv not found."
    echo "Creating a minimal language configuration."
    mkdir -p config
    printf "lang,label\neng,English\ndeu,German\nfra,French\n" > config/languages.csv
  fi

  awk -F',' '
    NR == 1 { next }
    NF >= 2 { printf "  %s - %s\n", $1, $2 }
  ' config/languages.csv

  echo ""
}

add_more_languages() {
  LANGUAGES_CHANGED=0

  read -r -p "Do you want to add more languages before building the database? [y/N] " ADD_LANGS

  case "$ADD_LANGS" in
    y|Y|yes|YES)
      echo ""
      echo "Add languages one at a time."
      echo "Use this format:"
      echo ""
      echo "  swe,Swedish"
      echo "  spa,Spanish"
      echo "  ita,Italian"
      echo ""
      echo "Press Enter on an empty line when finished."
      echo ""

      while true; do
        read -r -p "Language code and label: " LINE

        if [ -z "$LINE" ]; then
          break
        fi

        IFS=',' read -r LANG_CODE LANG_LABEL EXTRA <<< "$LINE"

        LANG_CODE="$(printf "%s" "$LANG_CODE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        LANG_LABEL="$(printf "%s" "${LANG_LABEL:-}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        if [ -z "$LANG_CODE" ]; then
          echo "Skipping empty language code."
          continue
        fi

        if [ -z "$LANG_LABEL" ]; then
          LANG_LABEL="$LANG_CODE"
        fi

        if ! printf "%s" "$LANG_CODE" | grep -Eq '^[A-Za-z0-9_-]+$'; then
          echo "Skipping invalid language code: $LANG_CODE"
          echo "Use codes such as eng, deu, fra, swe, spa."
          continue
        fi

        if grep -qE "^${LANG_CODE}," config/languages.csv; then
          echo "Language already exists: $LANG_CODE"
        else
          printf "%s,%s\n" "$LANG_CODE" "$LANG_LABEL" >> config/languages.csv
          echo "Added: $LANG_CODE - $LANG_LABEL"
          LANGUAGES_CHANGED=1
        fi
      done
      ;;

    *)
      echo "No extra languages added."
      ;;
  esac

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
add_more_languages
install_r_packages
build_database_if_needed
launch_app
