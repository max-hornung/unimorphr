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
clean_lib <- file.path(tempdir(), "renv_clean_lib")
dir.create(clean_lib, recursive = TRUE, showWarnings = FALSE)
message("Using isolated library at: ", clean_lib)
Sys.setenv(RENV_PATHS_LIBRARY = clean_lib)

# ── 3. Initialise renv in the project ──────────────────────────────────────
message("Initialising renv...")
renv::init(
  bare    = TRUE,
  restart = FALSE
)

# ── 4. Install only the three required packages ────────────────────────────
# IMPORTANT: use only stable CRAN for ALL packages, including duckdb.
# r-universe nightly builds (e.g. 1.5.4.9002) only have macOS binaries —
# Windows and Linux users end up compiling from source, which is slow and
# can fail. The stable CRAN release has pre-built binaries for all platforms.
message("Installing shiny, DBI, duckdb from CRAN stable...")
options(repos = c(CRAN = "https://cloud.r-project.org"))
renv::install(c("shiny", "DBI", "duckdb"))

# ── 5. Snapshot only those three packages ──────────────────────────────────
message("Writing renv.lock...")
renv::snapshot(
  packages = c("shiny", "DBI", "duckdb"),
  prompt   = FALSE
)

message("")
message("Done. renv.lock has been written with stable CRAN versions.")
message("These versions have pre-built binaries for macOS, Windows, and Linux.")
message("")
message("Commit it to your repository:")
message("  git add renv.lock")
message("  git commit -m 'Regenerate renv lockfile with stable CRAN duckdb'")
message("  git push")
