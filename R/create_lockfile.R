# create_lockfile.R
# Run this once in your project directory to generate renv.lock.
# Installs ONLY shiny, DBI, and duckdb (plus their true dependencies)
# into an isolated temporary library — your personal R library is never
# read or modified.
#
# Usage (from project root):
#   Rscript --vanilla create_lockfile.R

# ── 1. Install renv into the user library if not already there ─────────────
if (!requireNamespace("renv", quietly = TRUE)) {
  message("Installing renv...")
  install.packages("renv", repos = "https://cloud.r-project.org")
}

# ── 2. Point renv at a clean, empty library ────────────────────────────────
# This is the key step that prevents your personal library from bleeding in.
# We create a fresh directory and tell renv to use ONLY that.
clean_lib <- file.path(tempdir(), "renv_clean_lib")
dir.create(clean_lib, recursive = TRUE, showWarnings = FALSE)

message("Using isolated library at: ", clean_lib)
message("Your personal R library will not be touched.")

# Override renv's library path for this session only.
Sys.setenv(RENV_PATHS_LIBRARY = clean_lib)

# ── 3. Initialise renv in the project ──────────────────────────────────────
message("Initialising renv...")
renv::init(
  bare    = TRUE,   # do not copy packages from existing library
  restart = FALSE   # do not restart R (we are in a script)
)

# ── 4. Install only the three required packages ────────────────────────────
message("Installing shiny, DBI, duckdb into isolated library...")
message("(duckdb pre-built binary fetched from r-universe — no compilation)")

options(repos = c(
  duckdb = "https://duckdb.r-universe.dev",
  CRAN   = "https://cloud.r-project.org"
))

# Install explicitly by name — do not scan the broader project.
renv::install(c("shiny", "DBI", "duckdb"))

# ── 5. Snapshot only those three packages ──────────────────────────────────
# type = "explicit" + packages = ... means: record exactly these three and
# their true dependencies, nothing else.
message("Writing renv.lock...")
renv::snapshot(
  packages = c("shiny", "DBI", "duckdb"),
  type     = "explicit",
  prompt   = FALSE
)

message("")
message("Done. renv.lock has been written with exactly 3 top-level packages.")
message("Commit it to your repository:")
message("  git add renv.lock")
message("  git commit -m 'Add renv lockfile'")
message("  git push")
