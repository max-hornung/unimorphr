$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Self-fix execution policy so colleagues don't hit "scripts are disabled".
# We only change the CurrentUser scope — no admin rights required.
# ---------------------------------------------------------------------------
$ep = Get-ExecutionPolicy -Scope CurrentUser
if ($ep -eq "Restricted" -or $ep -eq "Undefined") {
    Write-Host "Setting PowerShell execution policy to RemoteSigned for current user."
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}

$RepoUrl   = "https://github.com/max-hornung/unimorphr.git"
$AppDir    = Join-Path $env:USERPROFILE "unimorphr"
$ShinyPort = 3838

Write-Host ""
Write-Host "UniMorphR Windows installer and launcher"
Write-Host "========================================"
Write-Host ""

function Find-Git {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) { return $git.Source }

    $possible = @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe"
    )
    foreach ($p in $possible) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Find-Rscript {
    $rscript = Get-Command Rscript -ErrorAction SilentlyContinue
    if ($rscript) { return $rscript.Source }

    $possible = Get-ChildItem "C:\Program Files\R" -Recurse -Filter "Rscript.exe" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if ($possible) { return $possible.FullName }
    return $null
}

function Ensure-Winget {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host "winget was not found."
        Write-Host "Please install Git and R manually, then run this command again."
        exit 1
    }
}

function Ensure-Git {
    $git = Find-Git
    if ($git) {
        Write-Host "Git found: $git"
        return $git
    }

    Write-Host "Git not found. Installing Git with winget..."
    Ensure-Winget
    winget install --id Git.Git -e --source winget `
        --accept-package-agreements --accept-source-agreements

    $git = Find-Git
    if (-not $git) {
        Write-Host "Git was installed but could not be found in this session."
        Write-Host "Please close PowerShell, open it again, and rerun the command."
        exit 1
    }
    return $git
}

function Ensure-R {
    $rscript = Find-Rscript
    if ($rscript) {
        Write-Host "R found: $rscript"
        return $rscript
    }

    Write-Host "R not found. Installing R with winget..."
    Ensure-Winget
    winget install --id RProject.R -e --source winget `
        --accept-package-agreements --accept-source-agreements

    $rscript = Find-Rscript
    if (-not $rscript) {
        Write-Host "R was installed but Rscript could not be found in this session."
        Write-Host "Please close PowerShell, open it again, and rerun the command."
        exit 1
    }
    return $rscript
}

function Clone-Or-Update-Repo {
    param([string]$Git)

    if (Test-Path (Join-Path $AppDir ".git")) {
        Write-Host ""
        Write-Host "Updating existing app folder: $AppDir"
        & $Git -C $AppDir pull --ff-only
    } elseif (Test-Path $AppDir) {
        Write-Host ""
        Write-Host "The folder $AppDir already exists but is not a Git repository."
        Write-Host "Please rename or delete it, then rerun the command."
        exit 1
    } else {
        Write-Host ""
        Write-Host "Cloning app into: $AppDir"
        & $Git clone $RepoUrl $AppDir
    }

    Set-Location $AppDir
}

function Ensure-Language-File {
    $configDir = Join-Path $AppDir "config"
    $langFile  = Join-Path $configDir "languages.csv"

    if (-not (Test-Path $langFile)) {
        Write-Host "config/languages.csv not found. Creating a default one."
        New-Item -ItemType Directory -Force -Path $configDir | Out-Null
        "lang,label"   | Out-File  -FilePath $langFile -Encoding utf8
        "eng,English"  | Add-Content -Path $langFile -Encoding utf8
        "deu,German"   | Add-Content -Path $langFile -Encoding utf8
        "fra,French"   | Add-Content -Path $langFile -Encoding utf8
    }
    return $langFile
}

function Show-Languages {
    param([string]$LangFile)

    Write-Host ""
    Write-Host "Current languages in config/languages.csv:"
    Write-Host "------------------------------------------"
    Import-Csv $LangFile | ForEach-Object {
        Write-Host ("  {0,-8} {1}" -f $_.lang, $_.label)
    }
    Write-Host ""
}

function Add-Languages-Interactively {
    param([string]$LangFile)

    $script:LanguagesChanged = $false
    $answer = Read-Host "Add more languages before building the database? [y/N]"

    if ($answer -notmatch "^(y|Y|yes|YES)$") {
        Write-Host "No extra languages added."
        Write-Host ""
        return
    }

    Write-Host ""
    Write-Host "Enter one language per line as:  code,Label"
    Write-Host "Examples:  swe,Swedish   spa,Spanish   ita,Italian"
    Write-Host "Press Enter on an empty line when finished."
    Write-Host ""

    while ($true) {
        $line = Read-Host "Language"
        if ([string]::IsNullOrWhiteSpace($line)) { break }

        $parts = $line.Split(",", 2)
        $code  = $parts[0].Trim().ToLower()
        $label = if ($parts.Count -gt 1) { $parts[1].Trim() } else { $code }

        if ($code -notmatch "^[a-z0-9_-]+$") {
            Write-Host "Invalid language code: $code — use codes like eng, deu, fra."
            continue
        }

        $existing = Import-Csv $LangFile | Where-Object { $_.lang -eq $code }
        if ($existing) {
            Write-Host "Already in list: $code"
            continue
        }

        "$code,$label" | Add-Content -Path $LangFile -Encoding utf8
        Write-Host "Added: $code - $label"
        $script:LanguagesChanged = $true
    }

    Show-Languages -LangFile $LangFile
}

function Install-R-Packages {
    param([string]$Rscript)

    Write-Host ""
    Write-Host ">>> Installing R packages."
    Write-Host "    duckdb pre-built binary will be fetched from r-universe."
    Write-Host "    This may take a few minutes on first run."

    & $Rscript --vanilla -e @"
# r-universe hosts pre-built Windows binaries for duckdb, avoiding the
# slow C++ source compilation that CRAN triggers by default on Windows.
options(repos = c(
  duckdb = 'https://duckdb.r-universe.dev',
  CRAN   = 'https://cloud.r-project.org'
))

pkgs    <- c('shiny', 'DBI', 'duckdb')
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) == 0L) {
  message('All required packages are already installed.')
} else {
  message('Installing: ', paste(missing, collapse = ', '))
  install.packages(missing, type = 'binary')
}
"@
    Write-Host "    OK: R packages ready."
}

function Build-Database-If-Needed {
    param([string]$Rscript)

    $dbFile  = Join-Path $AppDir "data\unimorph\unimorph.duckdb"
    $walFile = "$dbFile.wal"

    if ($script:LanguagesChanged) {
        Write-Host "Language list changed — rebuilding database."
        if (Test-Path $dbFile)  { Remove-Item $dbFile  -Force }
        if (Test-Path $walFile) { Remove-Item $walFile -Force }
    }

    if (-not (Test-Path $dbFile)) {
        Write-Host ""
        Write-Host ">>> Building local UniMorph database."
        Write-Host "    Downloads TSV files then imports into DuckDB."
        Write-Host "    This takes 1-5 minutes depending on language count and internet speed."
        Write-Host "    Progress is printed below."
        Write-Host ""
        & $Rscript --vanilla -e 'source("R/setup_local_database.R")'
        Write-Host "    OK: Database built."
    } else {
        Write-Host "    OK: Database already exists — skipping build."
    }
}

function Test-Port {
    param([int]$Port)
    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new(
            [System.Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        $listener.Stop()
        return $false
    } catch {
        return $true
    } finally {
        if ($listener) { try { $listener.Stop() } catch {} }
    }
}

function Launch-App {
    param([string]$Rscript)

    if (Test-Port -Port $ShinyPort) {
        Write-Host ""
        Write-Host "    WARN: Port $ShinyPort appears to be in use."
        Write-Host "    Edit `$ShinyPort at the top of this script to use a different port."
    }

    Write-Host ""
    Write-Host ">>> Starting Shiny app on port $ShinyPort."
    Write-Host "    Keep this PowerShell window open while the app is running."
    Write-Host "    Open your browser at:  http://127.0.0.1:$ShinyPort"
    Write-Host "    Press Ctrl-C to stop."
    Write-Host ""

    $env:SHINY_PORT = "$ShinyPort"

    & $Rscript --vanilla -e @"
port <- as.integer(Sys.getenv("SHINY_PORT", "3838"))
shiny::runApp(
  appDir = ".",
  host   = "127.0.0.1",
  port   = port,
  launch.browser = function(url) {
    message("Opening app at: ", url)
    utils::browseURL(url)
  }
)
"@
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

$Git     = Ensure-Git
$Rscript = Ensure-R

Clone-Or-Update-Repo -Git $Git

$LangFile = Ensure-Language-File
Show-Languages              -LangFile $LangFile
Add-Languages-Interactively -LangFile $LangFile

Install-R-Packages      -Rscript $Rscript
Build-Database-If-Needed -Rscript $Rscript
Launch-App              -Rscript $Rscript
