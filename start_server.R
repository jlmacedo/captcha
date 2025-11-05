#!/usr/bin/env Rscript

#' Start Anti-AI Captcha SaaS API Server
#'
#' Simple script to start the production API server
#'
#' Usage:
#'   Rscript start_server.R
#'
#' Or from R console:
#'   source("start_server.R")

cat("🚀 Starting Anti-AI Captcha SaaS API Server...\n\n")

# Check if required packages are installed
required_packages <- c("plumber", "DBI", "RSQLite", "jsonlite", "digest", "base64enc", "captcha")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("❌ Package '%s' is not installed.\n", pkg))
    cat(sprintf("Install it with: install.packages('%s')\n\n", pkg))
    stop(sprintf("Missing package: %s", pkg))
  }
}

cat("✅ All required packages are installed\n\n")

# Load libraries
library(plumber)
library(DBI)
library(RSQLite)
library(jsonlite)
library(captcha)

# Check environment variables
if (Sys.getenv("CAPTCHA_SECRET_KEY") == "") {
  cat("⚠️  WARNING: CAPTCHA_SECRET_KEY not set!\n")
  cat("Setting a default key for development (DO NOT USE IN PRODUCTION!)\n")
  Sys.setenv(CAPTCHA_SECRET_KEY = "development_secret_key_change_this_in_production_64_chars_min")
}

if (Sys.getenv("CAPTCHA_ADMIN_KEY") == "") {
  cat("⚠️  WARNING: CAPTCHA_ADMIN_KEY not set!\n")
  cat("Setting default: admin_secret\n")
  Sys.setenv(CAPTCHA_ADMIN_KEY = "admin_secret")
}

if (Sys.getenv("CAPTCHA_DB_PATH") == "") {
  Sys.setenv(CAPTCHA_DB_PATH = "captcha_saas.db")
}

cat("\n📋 Configuration:\n")
cat(sprintf("  Secret Key: %s\n", substr(Sys.getenv("CAPTCHA_SECRET_KEY"), 1, 20)))
cat(sprintf("  Admin Key: %s\n", Sys.getenv("CAPTCHA_ADMIN_KEY")))
cat(sprintf("  Database: %s\n", Sys.getenv("CAPTCHA_DB_PATH")))
cat("\n")

# Get configuration from command line or use defaults
args <- commandArgs(trailingOnly = TRUE)
host <- ifelse(length(args) >= 1, args[1], "0.0.0.0")
port <- ifelse(length(args) >= 2, as.numeric(args[2]), 8000)

# Source the API server
server_path <- file.path("inst", "api", "server.R")

if (!file.exists(server_path)) {
  # Try alternative path (if running from installed package)
  server_path <- system.file("api", "server.R", package = "captcha")

  if (server_path == "") {
    stop("❌ Cannot find server.R. Make sure you're in the package root directory.")
  }
}

cat(sprintf("📂 Loading server from: %s\n\n", server_path))
source(server_path)

# Start the server
cat("🌟 Starting server...\n")
cat(sprintf("   Host: %s\n", host))
cat(sprintf("   Port: %s\n\n", port))

cat("📖 API Documentation:\n")
cat(sprintf("   http://%s:%s/\n", ifelse(host == "0.0.0.0", "localhost", host), port))
cat(sprintf("   http://%s:%s/__docs__/\n\n", ifelse(host == "0.0.0.0", "localhost", host), port))

cat("🏥 Health Check:\n")
cat(sprintf("   http://%s:%s/health\n\n", ifelse(host == "0.0.0.0", "localhost", host), port))

cat("🎯 Quick Test:\n")
cat(sprintf("   curl http://%s:%s/health\n\n", ifelse(host == "0.0.0.0", "localhost", host), port))

cat("🔐 Create API Key:\n")
cat(sprintf('   curl -X POST http://%s:%s/api/v1/admin/keys \\\n', ifelse(host == "0.0.0.0", "localhost", host), port))
cat(sprintf('     -H "X-Admin-Key: %s" \\\n', Sys.getenv("CAPTCHA_ADMIN_KEY")))
cat('     -H "Content-Type: application/json" \\\n')
cat('     -d \'{"user_id":"user1","name":"Test","tier":"pro","monthly_limit":10000}\'\n\n')

cat("⏹️  Press Ctrl+C to stop the server\n\n")
cat(rep("=", 70), "\n\n", sep = "")

# Start the API
tryCatch({
  start_captcha_api(host = host, port = port)
}, error = function(e) {
  cat("\n❌ Error starting server:\n")
  cat(sprintf("   %s\n\n", e$message))

  if (grepl("address already in use", e$message, ignore.case = TRUE)) {
    cat("💡 The port is already in use. Try:\n")
    cat(sprintf("   Rscript start_server.R %s %s\n\n", host, port + 1))
  }

  quit(status = 1)
})
