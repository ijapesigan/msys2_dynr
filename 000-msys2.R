# MSYS2 + MinGW (Rtools-equivalent) portable setup — no admin required
# - Finds latest msys2-base-x86_64-YYYYMMDD.tar.xz from official repo/mirror
# - Extracts with 'archive' (preferred) or R.utils fallback (ext="xz")
# - Installs GCC/G++/GFortran, make, GSL, pkg-config via pacman
# - Configures PATH, PKG_CONFIG_PATH, PKG_CONFIG in ~/.Renviron
# - Verifies build tools

message_section <- function(title) {
  cat("\n", paste0(strrep("=", nchar(title)+4), "\n= ", title, " =\n", strrep("=", nchar(title)+4), "\n"), sep = "")
}
windows_only <- function() {
  if (.Platform$OS.type != "windows") stop("This script is intended for Windows.", call. = FALSE)
}
ensure_pkg <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}
append_unique_lines <- function(path, lines) {
  old <- if (file.exists(path)) readLines(path, warn = FALSE) else character(0)
  new <- old
  for (ln in lines) {
    key <- sub("^([A-Za-z0-9_]+)=.*$", "\\1=", ln)  # de-dup by VAR=
    if (!any(startsWith(trimws(old), key))) new <- c(new, ln)
  }
  if (!identical(new, old)) {
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    writeLines(new, path, useBytes = TRUE)
  }
}

# Prefer 'archive' for .tar.xz (no Rtools needed). Fallback to R.utils + utils::untar
extract_tar_xz <- function(xz_file, dest_dir) {
  if (requireNamespace("archive", quietly = TRUE)) {
    archive::archive_extract(xz_file, dir = dest_dir)
    return(invisible(TRUE))
  }
  ensure_pkg("R.utils")
  tar_file <- sub("\\.xz$", "", xz_file)
  R.utils::decompressFile(xz_file, destname = tar_file,
                          remove = FALSE, overwrite = TRUE, ext = "xz")
  utils::untar(tar_file, exdir = dest_dir)
  invisible(TRUE)
}

# Discover latest msys2-base archive URL from official repo or mirror
fetch_latest_url <- function() {
  bases <- c(
    "https://repo.msys2.org/distrib/x86_64/",
    "https://mirror.msys2.org/distrib/x86_64/"
  )
  pattern <- "msys2-base-x86_64-[0-9]{8}\\.tar\\.xz"
  for (base in bases) {
    html <- tryCatch(readLines(base, warn = FALSE), error = function(e) character(0))
    if (!length(html)) next
    m <- regmatches(html, gregexpr(pattern, html, perl = TRUE))
    files <- unique(unlist(m))
    files <- files[nzchar(files)]
    if (!length(files)) next
    latest <- sort(files, decreasing = TRUE)[1]
    url <- paste0(base, latest)
    ok <- tryCatch({ con <- url(url, "rb"); close(con); TRUE }, error = function(e) FALSE)
    if (ok) return(url)
  }
  stop("Could not discover a valid MSYS2 archive URL from known repositories.")
}

# --------------------------- RUN ---------------------------------------------
windows_only()
message_section("MSYS2 Portable Setup for R (No Admin)")

user_home    <- path.expand("~")
user_profile <- Sys.getenv("USERPROFILE", unset = user_home)
install_root <- user_profile
msys_dir     <- file.path(install_root, "msys64")
tmp_dir      <- tempdir()

cat("Install directory: ", msys_dir, "\n", sep = "")

# 1) Find latest archive
message_section("Discovering latest MSYS2 portable archive")
download_url <- fetch_latest_url()
archive_xz   <- file.path(tmp_dir, basename(download_url))
cat("Selected MSYS2 URL: ", download_url, "\n", sep = "")

# 2) Download
message_section("Downloading MSYS2 portable")
utils::download.file(download_url, destfile = archive_xz, mode = "wb", quiet = FALSE)
cat("Downloaded: ", archive_xz, "\n", sep = "")

# 3) Extract
message_section("Extracting archive")
if (!requireNamespace("archive", quietly = TRUE)) ensure_pkg("archive")
extract_tar_xz(archive_xz, install_root)
if (!dir.exists(msys_dir)) stop("Extraction failed: ", msys_dir, " not found.")
cat("Extracted to: ", msys_dir, "\n", sep = "")

# 4) Configure PATH and pkg-config
message_section("Configuring PATH and pkg-config variables")
mingw_bin     <- file.path(msys_dir, "mingw64", "bin")
msys_bin      <- file.path(msys_dir, "usr", "bin")
pkgconfig_dir <- file.path(msys_dir, "mingw64", "lib", "pkgconfig")

# For current R session
Sys.setenv(PATH = paste(mingw_bin, msys_bin, Sys.getenv("PATH"), sep = .Platform$path.sep))

# Persist in ~/.Renviron (forward slashes)
renv <- file.path(user_home, ".Renviron")
mingw_bin_f   <- gsub("\\\\", "/", mingw_bin)
msys_bin_f    <- gsub("\\\\", "/", msys_bin)
pkgconfig_f   <- gsub("\\\\", "/", pkgconfig_dir)
pkgconfig_exe <- gsub("\\\\", "/", file.path(mingw_bin, "pkg-config.exe"))

append_unique_lines(renv, c(
  sprintf('PATH="%s;%s;${PATH}"', mingw_bin_f, msys_bin_f),
  sprintf('PKG_CONFIG_PATH="%s;${PKG_CONFIG_PATH}"', pkgconfig_f),
  sprintf('PKG_CONFIG="%s"', pkgconfig_exe)
))

cat("Updated current session PATH and appended PATH/PKG_CONFIG_PATH/PKG_CONFIG to ", renv, "\n", sep = "")
cat("PATH entries:\n  ", mingw_bin, "\n  ", msys_bin, "\n", sep = "")
cat("PKG_CONFIG_PATH entry:\n  ", pkgconfig_dir, "\n", sep = "")

# 5) Install toolchains/GSL/pkg-config
message_section("Installing compilers, build tools, GSL, and pkg-config (pacman)")
bash_exe <- file.path(msys_bin, "bash.exe")
if (!file.exists(bash_exe)) stop("Could not find bash.exe at: ", bash_exe)

pacman_cmd <- paste(
  "pacman -Sy --noconfirm",
  "&& pacman -S --noconfirm mingw-w64-x86_64-toolchain make mingw-w64-x86_64-gsl mingw-w64-x86_64-pkgconf"
)

status <- system2(bash_exe, args = c("-lc", shQuote(pacman_cmd)), stdout = "", stderr = "")
if (!identical(status, 0L)) stop("pacman failed. Check internet access/proxy and try again.")
cat("Toolchains + GSL + pkg-config installed successfully.\n")

# 6) Verify
message_section("Verifying build tools and GSL/pkg-config in R")
cat("gcc:       ", Sys.which("gcc"),        "\n", sep = "")
cat("g++:       ", Sys.which("g++"),        "\n", sep = "")
cat("gfortran:  ", Sys.which("gfortran"),   "\n", sep = "")
cat("make:      ", Sys.which("make"),       "\n", sep = "")
cat("pkg-config:", Sys.which("pkg-config"), "\n", sep = "")

ensure_pkg("pkgbuild")
pkgbuild::has_build_tools(debug = TRUE)

cat("\nGSL via gsl-config:\n")
system("gsl-config --version", intern = FALSE, ignore.stdout = FALSE, ignore.stderr = FALSE)

cat("\nGSL via pkg-config:\n")
system("pkg-config --modversion gsl", intern = FALSE, ignore.stdout = FALSE, ignore.stderr = FALSE)
system("pkg-config --cflags --libs gsl", intern = FALSE, ignore.stdout = FALSE, ignore.stderr = FALSE)

cat("\nAll set!\n",
    "- You can compile packages from source now (with GSL discoverable via pkg-config).\n",
    "- We updated ~/.Renviron with PATH, PKG_CONFIG_PATH, and PKG_CONFIG.\n",
    "- Please RESTART R so future sessions pick up these settings automatically.\n",
    sep = "")
