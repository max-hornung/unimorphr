# create_lockfile.R
# Run this once in your project directory to generate renv.lock.
# Only the three packages in DESCRIPTION (and their true dependencies)
# will be captured — nothing from your personal R library bleeds in.
#
# Usage (from project root):
#   Rscript --vanilla create_lockfile.R

message("Installing renv...")
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}

message("Initialising renv (bare — does not touch your current library)...")
renv::init(bare = TRUE)

message("Installing packages listed in DESCRIPTION into the renv library...")
# Use r-universe for a pre-built duckdb binary (avoids slow C++ compilation).
options(repos = c(
  duckdb = "https://duckdb.r-universe.dev",
  CRAN   = "https://cloud.r-project.org"
))
renv::install()   # reads Imports: from DESCRIPTION

message("Writing renv.lock (type = 'explicit' — only DESCRIPTION packages)...")
renv::snapshot(type = "explicit")

message("")
message("Done. Commit renv.lock to your repository.")
message("Colleagues will get exactly these package versions when they run")
message("install_and_run.sh or install_and_run.ps1.")
