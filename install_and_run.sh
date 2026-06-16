#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/max-hornung/unimorphr.git"
APP_DIR="${APP_DIR:-$HOME/unimorphr}"
SHINY_PORT="${SHINY_PORT:-3838}"

echo ""
echo "UniMorphR installer and launcher"
echo "================================"
echo ""

run_with_sudo() {
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

install_system_dependencies() {
  OS="$(uname -s)"

  if [ "$OS" = "Darwin" ]; then
    echo "Detected macOS."

    if ! xcode-select -p >/dev/null 2>&1; then
      echo ""
      echo "Apple Command Line Tools are missing."
      echo "Starting the installer now."
      xcode-select --install
      echo ""
      echo "After the Apple Command Line Tools finish installing, rerun this command."
      exit 1
    fi

    if ! command -v brew >/dev/null 2>&1; then
      echo ""
      echo "Homebrew is not installed. Installing Homebrew first."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi

    echo ""
    echo "Installing macOS system dependencies."
    brew install git r libuv pkg-config

  elif [ "$OS" = "Linux" ]; then
    echo "Detected Linux."

    if command -v apt-get >/dev/null 2>&1; then
      echo ""
      echo "Installing Linux system dependencies with apt-get."
      run_with_sudo apt-get update
      run_with_sudo apt-get install -y \
        git \
        curl \
        ca-certificates \
        r-base \
        r-base-dev \
        build-essential \
        pkg-config \
        libuv1-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev

    elif command -v dnf >/dev/null 2>&1; then
      echo ""
      echo "Installing Linux system dependencies with dnf."
      run_with_sudo dnf install -y \
        git \
        curl \
        ca-certificates \
        R \
        R-devel \
        gcc \
        gcc-c++ \
        make \
        pkgconf-pkg-config \
        libuv-devel \
        libcurl-devel \
        openssl-devel \
        libxml2-devel

    elif command -v yum >/dev/null 2>&1; then
      echo ""
      echo "Installing Linux system dependencies with yum."
      run_with_sudo yum install -y \
        git \
        curl \
        ca-certificates \
        R \
        R-devel \
        gcc \
        gcc-c++ \
        make \
        pkgconf-pkg-config \
        libuv-devel \
        libcurl-devel \
        openssl-devel \
        libxml2-devel

    elif command -v pacman >/dev/null 2>&1; then
      echo ""
      echo "Installing Linux system dependencies with pacman."
      run_with_sudo pacman -Sy --noconfirm \
        git \
        curl \
        ca-certificates \
        r \
        base-devel \
        pkgconf \
        libuv \
        openssl \
        libxml2

    else
      echo ""
      echo "Could not detect a supported Linux package manager."
      echo "Please install Git, R, pkg-config, libuv, curl, OpenSSL, and XML development libraries manually."
      exit 1
    fi

  else
    echo ""
    echo "Unsupported operating system: $OS"
    echo "This script supports macOS and Linux."
    exit 1
  fi
}

check_required_commands() {
  echo ""
  echo "Checking required commands."

  if ! command -v git >/dev/null 2>&1; then
    echo "Git is not available after installation."
    exit 1
  fi

  if ! command -v Rscript >/dev/null 2>&1; then
    echo "Rscript is not available after installation."
    exit 1
  fi

  echo "Git found: $(command -v git)"
  echo "Rscript found: $(command -v Rscript)"
}

clone_or_update_repo() {
  echo ""

  if [ -d "$APP_DIR/.git" ]; then
    echo "Existing app folder found:"
    echo "$APP_DIR"

    if git -C "$APP_DIR" diff --quiet && git -C "$APP_DIR" diff --cached --quiet; then
      echo "Updating repository."
      git -C "$APP_DIR" pull --ff-only
    else
      echo ""
      echo "Local changes were detected, so the script will not run git pull."
      echo "This protects local edits such as changes to config/languages.csv."
      echo "The app will start from the local copy."
    fi

  elif [ -d "$APP_DIR" ]; then
    echo "The app folder already exists but is not a Git repository:"
    echo "$APP_DIR"
    echo ""
    echo "Please rename or delete this folder, then rerun this command."
    exit 1

  else
    echo "Cloning repository into:"
    echo "$APP_DIR"
    git clone "$REPO_URL" "$APP_DIR"
  fi

  cd "$APP_DIR"
}

ensure_language_file_exists() {
  if [ ! -f "config/languages.csv" ]; then
    echo ""
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
    NF >= 2 {
      gsub(/\r/, "", $1)
      gsub(/\r/, "", $2)
      printf "  %s - %s\n", $1, $2
    }
  ' config/languages.csv

  echo ""
}

language_exists() {
  code="$1"

  awk -F',' -v code="$code" '
    NR > 1 && $1 == code { found = 1 }
    END {
      if (found) exit 0
      exit 1
    }
  ' config/languages.csv
}

add_languages_interactively() {
  LANGUAGES_CHANGED=0

  read -r -p "Do you want to add another language before building the database? [y/N] " ANSWER

  case "$ANSWER" in
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
      ;;

    *)
      echo "No extra languages added."
      echo ""
      return
      ;;
  esac

  while true; do
    read -r -p "Language code and label: " LINE

    if [ -z "$LINE" ]; then
      break
    fi

    IFS=',' read -r LANG_CODE LANG_LABEL EXTRA <<< "$LINE"

    LANG_CODE="$(printf "%s" "$LANG_CODE" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    LANG_LABEL="$(printf "%s" "${LANG_LABEL:-}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    if [ -z "$LANG_CODE" ]; then
      echo "Skipping empty language code."
      continue
    fi

    if ! printf "%s" "$LANG_CODE" | grep -Eq '^[a-z0-9_-]+$'; then
      echo "Skipping invalid language code: $LANG_CODE"
      echo "Use codes such as eng, deu, fra, swe, spa."
      continue
    fi

    if [ -z "$LANG_LABEL" ]; then
      LANG_LABEL="$LANG_CODE"
    fi

    if printf "%s" "$LANG_LABEL" | grep -q ','; then
      echo "Skipping label because it contains a comma."
      echo "Please use a label such as Swedish, Spanish, or Italian."
      continue
    fi

    if language_exists "$LANG_CODE"; then
      echo "Language already exists: $LANG_CODE"
      continue
    fi

    printf "%s,%s\n" "$LANG_CODE" "$LANG_LABEL" >> config/languages.csv
    echo "Added: $LANG_CODE - $LANG_LABEL"
    LANGUAGES_CHANGED=1
  done

  echo ""
  echo "Final language list:"
  echo "--------------------"

  awk -F',' '
    NR == 1 { next }
    NF >= 2 {
      gsub(/\r/, "", $1)
      gsub(/\r/, "", $2)
      printf "  %s - %s\n", $1, $2
    }
  ' config/languages.csv

  echo ""
}

configure_r_build_environment() {
  export USE_BUNDLED_LIBUV=1

  if command -v brew >/dev/null 2>&1; then
    BREW_LIBUV_PREFIX="$(brew --prefix libuv 2>/dev/null || true)"

    if [ -n "$BREW_LIBUV_PREFIX" ]; then
      export PKG_CONFIG_PATH="$BREW_LIBUV_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    fi
  fi
}

install_r_packages() {
  echo ""
  echo "Installing required R packages if needed."

  configure_r_build_environment

  Rscript -e '
    options(repos = c(CRAN = "https://cloud.r-project.org"))

    pkgs <- c("fs", "sass", "bslib", "shiny", "DBI", "duckdb")
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
  WAL_FILE="data/unimorph/unimorph.duckdb.wal"

  if [ "${LANGUAGES_CHANGED:-0}" = "1" ]; then
    echo ""
    echo "Languages changed. Rebuilding database."
    rm -f "$DB_FILE"
    rm -f "$WAL_FILE"
  fi

  if [ ! -f "$DB_FILE" ]; then
    echo ""
    echo "Building local UniMorph database."
    echo "This may take a while on first run."
    Rscript -e 'source("R/setup_local_database.R")'
  else
    echo ""
    echo "Local database already exists."
  fi
}

launch_app() {
  echo ""
  echo "Starting Shiny app."
  echo "Keep this terminal window open while the app is running."
  echo ""

  export SHINY_PORT="$SHINY_PORT"

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
