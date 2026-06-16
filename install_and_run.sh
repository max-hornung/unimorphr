#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/max-hornung/unimorphr.git"
APP_DIR="${APP_DIR:-$HOME/unimorphr}"
SHINY_PORT="${SHINY_PORT:-3838}"

export RENV_CONFIG_AUTOLOADER_ENABLED=false
export USE_BUNDLED_LIBUV=1
export HOMEBREW_NO_AUTO_UPDATE=1

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

has_apt_package() {
  dpkg -s "$1" >/dev/null 2>&1
}

has_rpm_package() {
  rpm -q "$1" >/dev/null 2>&1
}

has_pacman_package() {
  pacman -Q "$1" >/dev/null 2>&1
}

has_brew_formula() {
  brew list --formula "$1" >/dev/null 2>&1
}

install_system_dependencies_macos() {
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

  missing=()

  if ! command -v git >/dev/null 2>&1 && ! has_brew_formula git; then
    missing+=("git")
  fi

  if ! command -v Rscript >/dev/null 2>&1 && ! has_brew_formula r; then
    missing+=("r")
  fi

  if ! command -v pkg-config >/dev/null 2>&1 && ! has_brew_formula pkg-config; then
    missing+=("pkg-config")
  fi

  if ! pkg-config --exists libuv >/dev/null 2>&1 && ! has_brew_formula libuv; then
    missing+=("libuv")
  fi

  if [ "${#missing[@]}" -gt 0 ]; then
    echo ""
    echo "Installing missing macOS dependencies:"
    printf "  %s\n" "${missing[@]}"
    brew install "${missing[@]}"
  else
    echo "Required macOS dependencies already look available."
  fi

  if command -v brew >/dev/null 2>&1; then
    BREW_LIBUV_PREFIX="$(brew --prefix libuv 2>/dev/null || true)"

    if [ -n "$BREW_LIBUV_PREFIX" ]; then
      export PKG_CONFIG_PATH="$BREW_LIBUV_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    fi
  fi
}

install_system_dependencies_linux() {
  echo "Detected Linux."

  if command -v apt-get >/dev/null 2>&1; then
    missing=()

    has_apt_package git || missing+=("git")
    has_apt_package curl || missing+=("curl")
    has_apt_package ca-certificates || missing+=("ca-certificates")
    has_apt_package r-base || missing+=("r-base")
    has_apt_package r-base-dev || missing+=("r-base-dev")
    has_apt_package build-essential || missing+=("build-essential")
    has_apt_package pkg-config || missing+=("pkg-config")
    has_apt_package libuv1-dev || missing+=("libuv1-dev")
    has_apt_package libcurl4-openssl-dev || missing+=("libcurl4-openssl-dev")
    has_apt_package libssl-dev || missing+=("libssl-dev")
    has_apt_package libxml2-dev || missing+=("libxml2-dev")

    if [ "${#missing[@]}" -gt 0 ]; then
      echo ""
      echo "Installing missing Linux dependencies with apt-get:"
      printf "  %s\n" "${missing[@]}"
      run_with_sudo apt-get update
      run_with_sudo apt-get install -y "${missing[@]}"
    else
      echo "Required apt packages already look installed."
    fi

  elif command -v dnf >/dev/null 2>&1; then
    missing=()

    has_rpm_package git || missing+=("git")
    has_rpm_package curl || missing+=("curl")
    has_rpm_package ca-certificates || missing+=("ca-certificates")
    has_rpm_package R || missing+=("R")
    has_rpm_package R-devel || missing+=("R-devel")
    has_rpm_package gcc || missing+=("gcc")
    has_rpm_package gcc-c++ || missing+=("gcc-c++")
    has_rpm_package make || missing+=("make")
    has_rpm_package pkgconf-pkg-config || missing+=("pkgconf-pkg-config")
    has_rpm_package libuv-devel || missing+=("libuv-devel")
    has_rpm_package libcurl-devel || missing+=("libcurl-devel")
    has_rpm_package openssl-devel || missing+=("openssl-devel")
    has_rpm_package libxml2-devel || missing+=("libxml2-devel")

    if [ "${#missing[@]}" -gt 0 ]; then
      echo ""
      echo "Installing missing Linux dependencies with dnf:"
      printf "  %s\n" "${missing[@]}"
      run_with_sudo dnf install -y "${missing[@]}"
    else
      echo "Required dnf packages already look installed."
    fi

  elif command -v yum >/dev/null 2>&1; then
    missing=()

    has_rpm_package git || missing+=("git")
    has_rpm_package curl || missing+=("curl")
    has_rpm_package ca-certificates || missing+=("ca-certificates")
    has_rpm_package R || missing+=("R")
    has_rpm_package R-devel || missing+=("R-devel")
    has_rpm_package gcc || missing+=("gcc")
    has_rpm_package gcc-c++ || missing+=("gcc-c++")
    has_rpm_package make || missing+=("make")
    has_rpm_package pkgconf-pkg-config || missing+=("pkgconf-pkg-config")
    has_rpm_package libuv-devel || missing+=("libuv-devel")
    has_rpm_package libcurl-devel || missing+=("libcurl-devel")
    has_rpm_package openssl-devel || missing+=("openssl-devel")
    has_rpm_package libxml2-devel || missing+=("libxml2-devel")

    if [ "${#missing[@]}" -gt 0 ]; then
      echo ""
      echo "Installing missing Linux dependencies with yum:"
      printf "  %s\n" "${missing[@]}"
      run_with_sudo yum install -y "${missing[@]}"
    else
      echo "Required yum packages already look installed."
    fi

  elif command -v pacman >/dev/null 2>&1; then
    missing=()

    has_pacman_package git || missing+=("git")
    has_pacman_package curl || missing+=("curl")
    has_pacman_package ca-certificates || missing+=("ca-certificates")
    has_pacman_package r || missing+=("r")
    has_pacman_package base-devel || missing+=("base-devel")
    has_pacman_package pkgconf || missing+=("pkgconf")
    has_pacman_package libuv || missing+=("libuv")
    has_pacman_package openssl || missing+=("openssl")
    has_pacman_package libxml2 || missing+=("libxml2")

    if [ "${#missing[@]}" -gt 0 ]; then
      echo ""
      echo "Installing missing Linux dependencies with pacman:"
      printf "  %s\n" "${missing[@]}"
      run_with_sudo pacman -Sy --noconfirm "${missing[@]}"
    else
      echo "Required pacman packages already look installed."
    fi

  else
    echo ""
    echo "Could not detect a supported Linux package manager."
    echo "Please install Git, R, pkg-config, libuv, curl, OpenSSL, and XML development libraries manually."
    exit 1
  fi
}

install_system_dependencies() {
  OS="$(uname -s)"

  if [ "$OS" = "Darwin" ]; then
    install_system_dependencies_macos
  elif [ "$OS" = "Linux" ]; then
    install_system_dependencies_linux
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
    echo "Git is not available."
    exit 1
  fi

  if ! command -v Rscript >/dev/null 2>&1; then
    echo "Rscript is not available."
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

install_r_packages() {
  echo ""
  echo "Checking required R packages."

  Rscript --vanilla -e '
    options(repos = c(CRAN = "https://cloud.r-project.org"))

    pkgs <- c("shiny", "DBI", "duckdb")
    missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]

    if (length(missing) == 0) {
      message("All required R packages are already installed.")
      quit(save = "no")
    }

    message("Installing missing R packages: ", paste(missing, collapse = ", "))

    ncpus <- max(1L, parallel::detectCores(logical = TRUE) - 1L)

    install.packages(
      missing,
      Ncpus = ncpus
    )
  '
}

rebuild_database() {
  DB_FILE="data/unimorph/unimorph.duckdb"
  WAL_FILE="data/unimorph/unimorph.duckdb.wal"

  echo ""
  echo "Rebuilding local UniMorph database."
  echo "This may take a while."

  rm -f "$DB_FILE"
  rm -f "$WAL_FILE"

  Rscript --vanilla -e 'source("R/setup_local_database.R")'
}

launch_app() {
  echo ""
  echo "Starting Shiny app."
  echo "Keep this terminal window open while the app is running."
  echo ""

  export SHINY_PORT="$SHINY_PORT"

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
}

install_system_dependencies
check_required_commands
clone_or_update_repo
show_languages
add_languages_interactively
install_r_packages
rebuild_database
launch_app
