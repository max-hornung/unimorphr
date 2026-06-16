
set -euo pipefail

REPO_URL="https://github.com/max-hornung/unimorphr.git"
APP_DIR="${APP_DIR:-$HOME/unimorphr}"
SHINY_PORT="${SHINY_PORT:-3838}"
LANG_FLAG_FILE=""   # set after APP_DIR is confirmed

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()    { echo ""; echo ">>> $*"; }
success() { echo "    OK: $*"; }
warn()    { echo "    WARN: $*"; }
die()     { echo ""; echo "ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. System dependencies
# ---------------------------------------------------------------------------

install_system_dependencies() {
  local os
  os="$(uname -s)"

  # ---- macOS ----------------------------------------------------------------
  if [ "$os" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      info "Installing Homebrew (required for Git and R on macOS)."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # shellcheck disable=SC1091
      if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi

    local brew_pkgs=()
    command -v git      >/dev/null 2>&1 || brew_pkgs+=(git)
    command -v Rscript  >/dev/null 2>&1 || brew_pkgs+=(r)

    if [ "${#brew_pkgs[@]}" -gt 0 ]; then
      info "Installing via Homebrew: ${brew_pkgs[*]}"
      brew install "${brew_pkgs[@]}"
    fi
    return
  fi

  # ---- Linux ----------------------------------------------------------------
  if [ "$os" = "Linux" ]; then

    if command -v apt-get >/dev/null 2>&1; then
      # Debian / Ubuntu
      # Always ensure dev headers are present — they are needed to compile
      # R packages (especially duckdb) even if R itself is already installed.
      info "Ensuring system build dependencies are installed (apt)."
      sudo apt-get update -qq
      sudo apt-get install -y --no-install-recommends \
        git \
        r-base \
        r-base-dev \
        build-essential \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libfontconfig1-dev \
        zlib1g-dev

    elif command -v dnf >/dev/null 2>&1; then
      info "Ensuring system build dependencies are installed (dnf)."
      sudo dnf install -y \
        git R R-devel gcc gcc-c++ make \
        libcurl-devel openssl-devel libxml2-devel zlib-devel

    elif command -v yum >/dev/null 2>&1; then
      info "Ensuring system build dependencies are installed (yum)."
      sudo yum install -y \
        git R R-devel gcc gcc-c++ make \
        libcurl-devel openssl-devel libxml2-devel zlib-devel

    elif command -v pacman >/dev/null 2>&1; then
      info "Ensuring system build dependencies are installed (pacman)."
      sudo pacman -Sy --noconfirm \
        git r base-devel curl openssl libxml2 zlib

    else
      warn "Could not detect a supported package manager."
      warn "Please install Git, R, and R development headers manually."
    fi
    return
  fi

  die "Unsupported operating system: $os — please install Git and R manually."
}

check_required_commands() {
  command -v git     >/dev/null 2>&1 || die "git is not available. Install it and re-run."
  command -v Rscript >/dev/null 2>&1 || die "Rscript is not available. Install R and re-run."
}

# ---------------------------------------------------------------------------
# 2. Clone / update repo
# ---------------------------------------------------------------------------

clone_or_update_repo() {
  if [ -d "$APP_DIR/.git" ]; then
    info "Updating existing repository at: $APP_DIR"
    git -C "$APP_DIR" pull --ff-only
  else
    info "Cloning repository into: $APP_DIR"
    git clone "$REPO_URL" "$APP_DIR"
  fi

  cd "$APP_DIR"

  # Temp file used to pass LANGUAGES_CHANGED back from subshell-free context.
  LANG_FLAG_FILE="$(mktemp)"
  echo "0" > "$LANG_FLAG_FILE"
}

# ---------------------------------------------------------------------------
# 3. Language configuration
# ---------------------------------------------------------------------------

show_languages() {
  info "Languages currently in config/languages.csv"

  if [ ! -f "config/languages.csv" ]; then
    warn "config/languages.csv not found — creating a default one."
    mkdir -p config
    printf "lang,label\neng,English\ndeu,German\nfra,French\n" > config/languages.csv
  fi

  awk -F',' 'NR>1 && NF>=2 { printf "    %-8s %s\n", $1, $2 }' config/languages.csv
}

add_more_languages() {
  local answer
  read -r -p "Add more languages before building the database? [y/N] " answer

  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "    No extra languages added."; return ;;
  esac

  echo ""
  echo "    Enter one language per line in the format:  code,Label"
  echo "    Examples:  swe,Swedish   spa,Spanish   ita,Italian"
  echo "    Press Enter on an empty line when finished."
  echo ""

  while true; do
    read -r -p "    Language: " LINE
    [ -z "$LINE" ] && break

    IFS=',' read -r LANG_CODE LANG_LABEL _ <<< "$LINE"
    LANG_CODE="$(echo "$LANG_CODE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    LANG_LABEL="$(echo "${LANG_LABEL:-}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$LANG_LABEL" ] && LANG_LABEL="$LANG_CODE"

    if ! echo "$LANG_CODE" | grep -Eq '^[A-Za-z0-9_-]+$'; then
      warn "Invalid language code '$LANG_CODE' — skipped."
      continue
    fi

    if grep -qE "^${LANG_CODE}," config/languages.csv 2>/dev/null; then
      warn "Already in list: $LANG_CODE"
    else
      printf "%s,%s\n" "$LANG_CODE" "$LANG_LABEL" >> config/languages.csv
      echo "    Added: $LANG_CODE ($LANG_LABEL)"
      echo "1" > "$LANG_FLAG_FILE"
    fi
  done

  echo ""
  echo "    Final language list:"
  awk -F',' 'NR>1 && NF>=2 { printf "    %-8s %s\n", $1, $2 }' config/languages.csv
}

# ---------------------------------------------------------------------------
# 4. R package installation
# ---------------------------------------------------------------------------

install_r_packages() {
  info "Installing R packages."

  # Strategy:
  # 1. If renv.lock exists → use renv::restore() (fast, reproducible).
  # 2. Otherwise → install directly, but use r-universe for a pre-built
  #    duckdb binary so macOS/Linux users don't have to wait for compilation.

  if [ -f "renv.lock" ]; then
    echo "    Found renv.lock — using renv for reproducible install."
    echo "    This may take a few minutes on first run."

    RENV_CONFIG_AUTOLOADER_ENABLED=false \
    Rscript --vanilla -e '
      if (!requireNamespace("renv", quietly = TRUE)) {
        install.packages("renv", repos = "https://cloud.r-project.org")
      }
      renv::restore(prompt = FALSE)
    '
  else
    echo "    No renv.lock found — installing packages directly."
    echo "    duckdb will be fetched as a pre-built binary where possible."
    echo "    This may take several minutes on first run."

    Rscript --vanilla -e '
      # r-universe provides pre-built duckdb binaries for macOS and Linux,
      # avoiding the slow source compilation that is the default on CRAN.
      options(repos = c(
        duckdb   = "https://duckdb.r-universe.dev",
        CRAN     = "https://cloud.r-project.org"
      ))

      pkgs    <- c("shiny", "DBI", "duckdb")
      missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]

      if (length(missing) == 0L) {
        message("All required packages are already installed.")
      } else {
        message("Installing: ", paste(missing, collapse = ", "))
        # type = "binary" is a no-op on Linux but speeds things up on macOS.
        install.packages(missing, type = "binary")
      }
    '
  fi

  success "R packages ready."
}

# ---------------------------------------------------------------------------
# 5. Database build
# ---------------------------------------------------------------------------

build_database_if_needed() {
  local db_file="data/unimorph/unimorph.duckdb"
  local langs_changed
  langs_changed="$(cat "$LANG_FLAG_FILE")"

  if [ "$langs_changed" = "1" ]; then
    info "Language list changed — rebuilding database."
    rm -f "$db_file" "${db_file}.wal"
  fi

  if [ -f "$db_file" ]; then
    success "Database already exists — skipping build."
    return
  fi

  info "Building local UniMorph database (downloads TSV files + imports into DuckDB)."
  echo "    This takes 1–5 minutes depending on the number of languages and your"
  echo "    internet speed. Progress is printed below."
  echo ""

  Rscript --vanilla -e 'source("R/setup_local_database.R")'

  success "Database built at: $db_file"
}

# ---------------------------------------------------------------------------
# 6. Port check + launch
# ---------------------------------------------------------------------------

check_port() {
  # Try ss first, fall back to lsof, then just skip the check.
  local busy=0

  if command -v ss >/dev/null 2>&1; then
    ss -tln 2>/dev/null | grep -q ":${SHINY_PORT} " && busy=1
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$SHINY_PORT" -sTCP:LISTEN >/dev/null 2>&1 && busy=1
  fi

  if [ "$busy" = "1" ]; then
    warn "Port $SHINY_PORT appears to be in use."
    warn "Set a different port with:  SHINY_PORT=4242 bash install_and_run.sh"
  fi
}

launch_app() {
  check_port

  info "Starting Shiny app on port $SHINY_PORT."
  echo "    Keep this terminal open while the app is running."
  echo "    Open your browser at:  http://127.0.0.1:${SHINY_PORT}"
  echo "    Press Ctrl-C to stop."
  echo ""

  SHINY_PORT="$SHINY_PORT" \
  Rscript --vanilla -e '
    port <- as.integer(Sys.getenv("SHINY_PORT", "3838"))
    shiny::runApp(
      appDir = ".",
      host   = "127.0.0.1",
      port   = port,
      launch.browser = function(url) {
        message("Opening: ", url)
        utils::browseURL(url)
      }
    )
  '
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

cleanup() {
  [ -n "$LANG_FLAG_FILE" ] && rm -f "$LANG_FLAG_FILE"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo ""
echo "UniMorphR — installer and launcher"
echo "==================================="

install_system_dependencies
check_required_commands
clone_or_update_repo
show_languages
add_more_languages
install_r_packages
build_database_if_needed
launch_app
