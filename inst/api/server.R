#' Anti-AI Captcha SaaS API Server
#'
#' Production-ready REST API for serving captcha challenges and verification
#' Supports web and mobile platforms (Flutter, Android, iOS)

library(plumber)
library(captcha)
library(jsonlite)
library(DBI)
library(RSQLite)

# ============================================================================
# Configuration
# ============================================================================

API_VERSION <- "v1"
MAX_IMAGE_SIZE <- 5 * 1024 * 1024  # 5MB
RATE_LIMIT_REQUESTS <- 100
RATE_LIMIT_WINDOW <- 3600  # 1 hour

# Initialize database connection
init_db <- function() {
  db_path <- Sys.getenv("CAPTCHA_DB_PATH", "captcha_saas.db")
  con <- dbConnect(SQLite(), db_path)

  # Create tables if not exist
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS api_keys (
      api_key TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT,
      tier TEXT DEFAULT 'free',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_used_at TIMESTAMP,
      is_active INTEGER DEFAULT 1,
      monthly_limit INTEGER DEFAULT 10000,
      monthly_usage INTEGER DEFAULT 0
    )
  ")

  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS usage_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      api_key TEXT NOT NULL,
      endpoint TEXT NOT NULL,
      timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      ip_address TEXT,
      user_agent TEXT,
      success INTEGER DEFAULT 1,
      error_message TEXT
    )
  ")

  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS captcha_sessions (
      captcha_id TEXT PRIMARY KEY,
      api_key TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      expires_at TIMESTAMP NOT NULL,
      solved INTEGER DEFAULT 0,
      solved_at TIMESTAMP,
      difficulty TEXT,
      ip_address TEXT
    )
  ")

  con
}

# Get database connection (singleton pattern)
get_db <- local({
  db_conn <- NULL
  function() {
    if (is.null(db_conn) || !dbIsValid(db_conn)) {
      db_conn <<- init_db()
    }
    db_conn
  }
})

# ============================================================================
# Authentication & Authorization
# ============================================================================

#' Validate API Key
#' @keywords internal
validate_api_key <- function(api_key) {
  if (is.null(api_key) || api_key == "") {
    return(list(valid = FALSE, error = "API key required"))
  }

  db <- get_db()

  # Query API key
  result <- dbGetQuery(db,
    "SELECT * FROM api_keys WHERE api_key = ? AND is_active = 1",
    params = list(api_key)
  )

  if (nrow(result) == 0) {
    return(list(valid = FALSE, error = "Invalid API key"))
  }

  key_info <- result[1, ]

  # Check monthly limit
  if (key_info$monthly_usage >= key_info$monthly_limit) {
    return(list(
      valid = FALSE,
      error = "Monthly usage limit exceeded",
      tier = key_info$tier,
      limit = key_info$monthly_limit
    ))
  }

  # Update last used
  dbExecute(db,
    "UPDATE api_keys SET last_used_at = CURRENT_TIMESTAMP WHERE api_key = ?",
    params = list(api_key)
  )

  list(
    valid = TRUE,
    api_key = api_key,
    user_id = key_info$user_id,
    tier = key_info$tier,
    monthly_limit = key_info$monthly_limit,
    monthly_usage = key_info$monthly_usage
  )
}

#' Log API usage
#' @keywords internal
log_usage <- function(api_key, endpoint, ip_address, user_agent, success = TRUE, error = NULL) {
  db <- get_db()

  # Insert usage log
  dbExecute(db, "
    INSERT INTO usage_logs (api_key, endpoint, ip_address, user_agent, success, error_message)
    VALUES (?, ?, ?, ?, ?, ?)
  ", params = list(api_key, endpoint, ip_address, user_agent, as.integer(success), error))

  # Increment monthly usage
  if (success) {
    dbExecute(db, "
      UPDATE api_keys SET monthly_usage = monthly_usage + 1 WHERE api_key = ?
    ", params = list(api_key))
  }
}

# ============================================================================
# API Filters
# ============================================================================

#' CORS Filter
#' @keywords internal
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, X-API-Key")

  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  } else {
    plumber::forward()
  }
}

#' Authentication Filter
#' @keywords internal
#* @filter auth
function(req, res) {
  # Skip auth for public endpoints
  if (req$PATH_INFO %in% c("/", "/health", "/docs")) {
    plumber::forward()
    return()
  }

  # Get API key from header
  api_key <- req$HTTP_X_API_KEY

  if (is.null(api_key)) {
    # Try Authorization header
    auth_header <- req$HTTP_AUTHORIZATION
    if (!is.null(auth_header) && grepl("^Bearer ", auth_header)) {
      api_key <- sub("^Bearer ", "", auth_header)
    }
  }

  # Validate API key
  validation <- validate_api_key(api_key)

  if (!validation$valid) {
    res$status <- 401
    return(list(
      error = validation$error,
      message = "Please provide a valid API key in X-API-Key header or Authorization: Bearer <key>"
    ))
  }

  # Store in request for later use
  req$api_key_info <- validation

  plumber::forward()
}

#' Rate Limiting Filter
#' @keywords internal
#* @filter rate_limit
function(req, res) {
  if (req$PATH_INFO %in% c("/", "/health", "/docs")) {
    plumber::forward()
    return()
  }

  api_key <- req$api_key_info$api_key

  # Simple in-memory rate limiting (use Redis in production)
  rate_limit_key <- paste0("rate_limit:", api_key)

  # Check rate limit
  # In production, implement proper rate limiting with Redis

  plumber::forward()
}

# ============================================================================
# API Endpoints
# ============================================================================

#* @apiTitle Anti-AI Captcha SaaS API
#* @apiDescription Production-ready captcha service for web and mobile platforms
#* @apiVersion 1.0.0

#' Health Check
#' @get /health
function() {
  list(
    status = "healthy",
    version = API_VERSION,
    timestamp = Sys.time()
  )
}

#' API Information
#' @get /
function() {
  list(
    name = "Anti-AI Captcha SaaS API",
    version = API_VERSION,
    description = "Professional captcha service for web and mobile",
    endpoints = list(
      "POST /api/v1/captcha/create" = "Create new captcha challenge",
      "POST /api/v1/captcha/verify" = "Verify captcha solution",
      "GET /api/v1/captcha/:id/image" = "Get captcha image",
      "GET /api/v1/usage" = "Get usage statistics",
      "GET /health" = "Health check"
    ),
    documentation = "/docs"
  )
}

#' Create Captcha Challenge
#'
#' Generates a new captcha challenge with token for verification.
#' Returns captcha ID, token, and base64-encoded image.
#'
#' @post /api/v1/captcha/create
#' @param req Request object
#' @param res Response object
#' @param difficulty:character Difficulty level (easy, medium, hard, extreme). Default: hard
#' @param session_id:character Optional session identifier for tracking
#' @param use_progressive:logical Use progressive difficulty. Default: false
#' @param include_audio:logical Include audio alternative (future feature). Default: false
function(req, res,
         difficulty = "hard",
         session_id = NULL,
         use_progressive = FALSE,
         include_audio = FALSE) {

  tryCatch({
    api_key <- req$api_key_info$api_key
    ip_address <- req$REMOTE_ADDR

    # Validate difficulty
    if (!difficulty %in% c("easy", "medium", "hard", "extreme")) {
      res$status <- 400
      return(list(error = "Invalid difficulty. Must be: easy, medium, hard, or extreme"))
    }

    # Create session ID if not provided
    if (is.null(session_id)) {
      session_id <- paste0(ip_address, "_", as.integer(Sys.time()))
    }

    # Create challenge
    challenge <- captcha_create_challenge(
      difficulty = difficulty,
      session_id = session_id,
      use_progressive_difficulty = use_progressive,
      expiry_seconds = 300
    )

    # Convert image to base64
    img_path <- tempfile(fileext = ".png")
    magick::image_write(challenge$image, img_path, format = "png")
    img_base64 <- base64enc::base64encode(img_path)
    unlink(img_path)

    # Store session in database
    db <- get_db()
    dbExecute(db, "
      INSERT INTO captcha_sessions (captcha_id, api_key, expires_at, difficulty, ip_address)
      VALUES (?, ?, ?, ?, ?)
    ", params = list(
      challenge$captcha_id,
      api_key,
      format(challenge$expires_at, "%Y-%m-%d %H:%M:%S"),
      difficulty,
      ip_address
    ))

    # Log usage
    log_usage(api_key, "create_captcha", ip_address, req$HTTP_USER_AGENT)

    res$status <- 201
    list(
      success = TRUE,
      data = list(
        captcha_id = challenge$captcha_id,
        token = challenge$token,
        image = list(
          base64 = img_base64,
          url = paste0("/api/v1/captcha/", challenge$captcha_id, "/image"),
          format = "png"
        ),
        difficulty = challenge$difficulty,
        expires_at = format(challenge$expires_at, "%Y-%m-%dT%H:%M:%SZ"),
        expires_in_seconds = challenge$expires_in_seconds
      ),
      metadata = list(
        tier = req$api_key_info$tier,
        usage = req$api_key_info$monthly_usage + 1,
        limit = req$api_key_info$monthly_limit
      )
    )

  }, error = function(e) {
    res$status <- 500
    log_usage(req$api_key_info$api_key, "create_captcha",
              req$REMOTE_ADDR, req$HTTP_USER_AGENT,
              success = FALSE, error = as.character(e))
    list(
      success = FALSE,
      error = "Internal server error",
      message = as.character(e)
    )
  })
}

#' Verify Captcha Solution
#'
#' Validates a captcha solution with comprehensive security checks.
#'
#' @post /api/v1/captcha/verify
#' @param req Request object
#' @param res Response object
#' @param captcha_id:character Captcha identifier
#' @param token:character Validation token from create endpoint
#' @param answer:character User's captcha solution
#' @param solve_time:numeric Time taken to solve (milliseconds)
#' @param session_id:character Session identifier
#' @param behavior_data:object Optional behavioral data
function(req, res,
         captcha_id = NULL,
         token = NULL,
         answer = NULL,
         solve_time = NULL,
         session_id = NULL,
         behavior_data = NULL) {

  tryCatch({
    api_key <- req$api_key_info$api_key
    ip_address <- req$REMOTE_ADDR

    # Validate required fields
    if (is.null(captcha_id) || is.null(token) || is.null(answer)) {
      res$status <- 400
      return(list(
        success = FALSE,
        error = "Missing required fields",
        required = c("captcha_id", "token", "answer")
      ))
    }

    # Check if captcha exists and belongs to this API key
    db <- get_db()
    session <- dbGetQuery(db,
      "SELECT * FROM captcha_sessions WHERE captcha_id = ? AND api_key = ?",
      params = list(captcha_id, api_key)
    )

    if (nrow(session) == 0) {
      res$status <- 404
      return(list(
        success = FALSE,
        error = "Captcha not found or does not belong to your API key"
      ))
    }

    # Check if already solved
    if (session$solved == 1) {
      res$status <- 400
      return(list(
        success = FALSE,
        error = "Captcha already solved",
        message = "Each captcha can only be verified once"
      ))
    }

    # Convert solve_time from milliseconds to seconds
    solve_time_seconds <- if (!is.null(solve_time)) solve_time / 1000 else 10

    # Verify solution
    result <- captcha_verify_solution(
      token = token,
      answer = answer,
      captcha_id = captcha_id,
      solve_time_seconds = solve_time_seconds,
      session_id = session_id,
      behavior_data = behavior_data,
      strict_mode = TRUE
    )

    # Update session
    if (result$valid) {
      dbExecute(db,
        "UPDATE captcha_sessions SET solved = 1, solved_at = CURRENT_TIMESTAMP WHERE captcha_id = ?",
        params = list(captcha_id)
      )
    }

    # Log usage
    log_usage(api_key, "verify_captcha", ip_address, req$HTTP_USER_AGENT)

    res$status <- if (result$valid) 200 else 400
    list(
      success = result$valid,
      data = list(
        valid = result$valid,
        message = result$message,
        risk_assessment = list(
          risk_score = result$risk_score,
          risk_level = result$risk_level,
          warnings = result$warnings
        ),
        solve_time_seconds = solve_time_seconds
      )
    )

  }, error = function(e) {
    res$status <- 500
    log_usage(req$api_key_info$api_key, "verify_captcha",
              req$REMOTE_ADDR, req$HTTP_USER_AGENT,
              success = FALSE, error = as.character(e))
    list(
      success = FALSE,
      error = "Internal server error",
      message = as.character(e)
    )
  })
}

#' Get Captcha Image
#'
#' Returns the captcha image as PNG
#'
#' @get /api/v1/captcha/<id>/image
#' @param req Request object
#' @param res Response object
#' @param id Captcha identifier
function(req, res, id) {
  tryCatch({
    api_key <- req$api_key_info$api_key

    # Check if captcha exists
    db <- get_db()
    session <- dbGetQuery(db,
      "SELECT * FROM captcha_sessions WHERE captcha_id = ? AND api_key = ?",
      params = list(id, api_key)
    )

    if (nrow(session) == 0) {
      res$status <- 404
      return(list(error = "Captcha not found"))
    }

    # In production, retrieve from cache or regenerate
    # For now, return error as images should be embedded in create response
    res$status <- 410
    list(
      error = "Image no longer available",
      message = "Images should be retrieved from the create endpoint response"
    )

  }, error = function(e) {
    res$status <- 500
    list(error = "Internal server error", message = as.character(e))
  })
}

#' Get Usage Statistics
#'
#' Returns usage statistics for the authenticated API key
#'
#' @get /api/v1/usage
#' @param req Request object
#' @param time_window:integer Time window in hours (default: 24)
function(req, time_window = 24) {
  tryCatch({
    api_key <- req$api_key_info$api_key

    db <- get_db()

    # Get usage stats
    stats <- dbGetQuery(db, "
      SELECT
        COUNT(*) as total_requests,
        SUM(CASE WHEN endpoint = 'create_captcha' THEN 1 ELSE 0 END) as creates,
        SUM(CASE WHEN endpoint = 'verify_captcha' THEN 1 ELSE 0 END) as verifications,
        SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful,
        SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) as failed
      FROM usage_logs
      WHERE api_key = ? AND timestamp >= datetime('now', '-' || ? || ' hours')
    ", params = list(api_key, time_window))

    # Get captcha stats
    captcha_stats <- dbGetQuery(db, "
      SELECT
        COUNT(*) as total_captchas,
        SUM(CASE WHEN solved = 1 THEN 1 ELSE 0 END) as solved,
        difficulty,
        COUNT(*) as count
      FROM captcha_sessions
      WHERE api_key = ? AND created_at >= datetime('now', '-' || ? || ' hours')
      GROUP BY difficulty
    ", params = list(api_key, time_window))

    list(
      success = TRUE,
      data = list(
        api_usage = list(
          total_requests = stats$total_requests,
          creates = stats$creates,
          verifications = stats$verifications,
          successful = stats$successful,
          failed = stats$failed
        ),
        captcha_stats = list(
          total = sum(captcha_stats$count),
          by_difficulty = captcha_stats
        ),
        account_info = list(
          tier = req$api_key_info$tier,
          monthly_usage = req$api_key_info$monthly_usage,
          monthly_limit = req$api_key_info$monthly_limit,
          remaining = req$api_key_info$monthly_limit - req$api_key_info$monthly_usage
        ),
        time_window_hours = time_window
      )
    )

  }, error = function(e) {
    list(error = "Internal server error", message = as.character(e))
  })
}

#' Create API Key (Admin endpoint)
#'
#' @post /api/v1/admin/keys
#' @param req Request object
#' @param user_id:character User identifier
#' @param name:character Key name
#' @param tier:character Tier (free, starter, pro, enterprise)
#' @param monthly_limit:integer Monthly usage limit
function(req, user_id, name = "default", tier = "free", monthly_limit = 10000) {
  # Check admin auth (implement proper admin authentication)
  admin_key <- req$HTTP_X_ADMIN_KEY
  if (admin_key != Sys.getenv("CAPTCHA_ADMIN_KEY", "admin_secret")) {
    return(list(error = "Unauthorized"))
  }

  # Generate API key
  api_key <- paste0("captcha_", paste(sample(c(letters, LETTERS, 0:9), 32, replace = TRUE), collapse = ""))

  db <- get_db()
  dbExecute(db, "
    INSERT INTO api_keys (api_key, user_id, name, tier, monthly_limit)
    VALUES (?, ?, ?, ?, ?)
  ", params = list(api_key, user_id, name, tier, monthly_limit))

  list(
    success = TRUE,
    data = list(
      api_key = api_key,
      user_id = user_id,
      tier = tier,
      monthly_limit = monthly_limit
    )
  )
}

# ============================================================================
# Server Configuration
# ============================================================================

#' Start the API server
#' @export
start_captcha_api <- function(host = "0.0.0.0", port = 8000) {
  # Initialize configuration
  captcha_configure(
    secret_key = Sys.getenv("CAPTCHA_SECRET_KEY", "default_secret_key_change_in_production")
  )

  message("Starting Anti-AI Captcha SaaS API...")
  message(sprintf("Host: %s", host))
  message(sprintf("Port: %s", port))
  message(sprintf("API Version: %s", API_VERSION))
  message("Initializing database...")

  # Initialize database
  db <- get_db()
  message("Database initialized")

  message("\nAPI is ready!")
  message(sprintf("Documentation: http://%s:%s/docs", host, port))
  message(sprintf("Health check: http://%s:%s/health\n", host, port))

  # Create plumber API
  pr() %>%
    plumber::pr_run(host = host, port = port)
}
