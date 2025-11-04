#' Security System for Anti-AI Captcha
#'
#' Provides cryptographic token generation, validation, rate limiting,
#' and session management for secure captcha operations.

#' Generate Secure Captcha Token
#'
#' Creates a cryptographically secure token tied to a specific captcha.
#' The token contains the captcha ID, answer hash, timestamp, and signature.
#'
#' @param captcha_id unique identifier for the captcha
#' @param answer the correct answer to the captcha
#' @param expiry_seconds how long the token is valid (default: 300 = 5 minutes)
#' @param secret_key secret key for signing (if NULL, uses session key)
#'
#' @return a list containing the token string and metadata
#'
#' @examples
#' token <- captcha_generate_token("12345", "abc123")
#'
#' @export
captcha_generate_token <- function(captcha_id,
                                   answer,
                                   expiry_seconds = 300,
                                   secret_key = NULL) {

  if (is.null(secret_key)) {
    secret_key <- get_session_secret()
  }

  # Create token payload
  timestamp <- as.numeric(Sys.time())
  expiry <- timestamp + expiry_seconds

  # Hash the answer (don't store plaintext)
  answer_hash <- digest_answer(answer, secret_key)

  # Create payload
  payload <- list(
    captcha_id = captcha_id,
    answer_hash = answer_hash,
    timestamp = timestamp,
    expiry = expiry,
    nonce = generate_nonce()
  )

  # Serialize and sign
  payload_string <- serialize_payload(payload)
  signature <- sign_payload(payload_string, secret_key)

  # Create token
  token <- paste0(payload_string, ".", signature)

  list(
    token = token,
    captcha_id = captcha_id,
    timestamp = timestamp,
    expiry = expiry,
    valid_for_seconds = expiry_seconds
  )
}

#' Validate Captcha Token and Answer
#'
#' Validates that a token is authentic, not expired, and that the provided
#' answer matches the expected answer.
#'
#' @param token the token string to validate
#' @param answer the user's attempted answer
#' @param captcha_id the captcha ID (for verification)
#' @param secret_key secret key for verification (if NULL, uses session key)
#' @param storage_backend backend for tracking attempts (default: memory)
#'
#' @return a list with `valid` (TRUE/FALSE) and `message` explaining the result
#'
#' @examples
#' result <- captcha_validate_token(token, "abc123", "12345")
#' if (result$valid) {
#'   print("Captcha solved correctly!")
#' }
#'
#' @export
captcha_validate_token <- function(token,
                                   answer,
                                   captcha_id,
                                   secret_key = NULL,
                                   storage_backend = NULL) {

  if (is.null(secret_key)) {
    secret_key <- get_session_secret()
  }

  if (is.null(storage_backend)) {
    storage_backend <- get_default_storage()
  }

  # Parse token
  token_parts <- strsplit(token, "\\.")[[1]]
  if (length(token_parts) != 2) {
    return(list(
      valid = FALSE,
      message = "Invalid token format",
      error = "TOKEN_FORMAT_INVALID"
    ))
  }

  payload_string <- token_parts[1]
  signature <- token_parts[2]

  # Verify signature
  expected_signature <- sign_payload(payload_string, secret_key)
  if (signature != expected_signature) {
    return(list(
      valid = FALSE,
      message = "Invalid token signature - possible tampering detected",
      error = "TOKEN_SIGNATURE_INVALID"
    ))
  }

  # Deserialize payload
  payload <- tryCatch(
    deserialize_payload(payload_string),
    error = function(e) NULL
  )

  if (is.null(payload)) {
    return(list(
      valid = FALSE,
      message = "Corrupted token payload",
      error = "TOKEN_CORRUPTED"
    ))
  }

  # Verify captcha ID matches
  if (payload$captcha_id != captcha_id) {
    return(list(
      valid = FALSE,
      message = "Token captcha ID mismatch",
      error = "TOKEN_ID_MISMATCH"
    ))
  }

  # Check expiry
  current_time <- as.numeric(Sys.time())
  if (current_time > payload$expiry) {
    return(list(
      valid = FALSE,
      message = "Token expired - please request a new captcha",
      error = "TOKEN_EXPIRED"
    ))
  }

  # Check if token already used
  if (is_token_used(payload$captcha_id, storage_backend)) {
    return(list(
      valid = FALSE,
      message = "Token already used - each captcha can only be solved once",
      error = "TOKEN_ALREADY_USED"
    ))
  }

  # Verify answer
  answer_hash <- digest_answer(answer, secret_key)
  if (answer_hash != payload$answer_hash) {
    # Record failed attempt
    record_attempt(
      captcha_id = captcha_id,
      success = FALSE,
      storage_backend = storage_backend
    )

    return(list(
      valid = FALSE,
      message = "Incorrect answer",
      error = "ANSWER_INCORRECT"
    ))
  }

  # Mark token as used
  mark_token_used(payload$captcha_id, storage_backend)

  # Record successful attempt
  record_attempt(
    captcha_id = captcha_id,
    success = TRUE,
    storage_backend = storage_backend
  )

  list(
    valid = TRUE,
    message = "Captcha solved correctly",
    captcha_id = captcha_id,
    solve_time = current_time - payload$timestamp
  )
}

#' Check Rate Limiting
#'
#' Determines if a session/IP has exceeded rate limits.
#'
#' @param session_id unique identifier for the session or IP address
#' @param max_attempts maximum attempts allowed in time window
#' @param time_window_seconds time window in seconds (default: 3600 = 1 hour)
#' @param storage_backend backend for tracking attempts
#'
#' @return list with `allowed` (TRUE/FALSE) and rate limit info
#'
#' @examples
#' result <- captcha_check_rate_limit("192.168.1.1")
#' if (!result$allowed) {
#'   print("Rate limit exceeded!")
#' }
#'
#' @export
captcha_check_rate_limit <- function(session_id,
                                     max_attempts = 10,
                                     time_window_seconds = 3600,
                                     storage_backend = NULL) {

  if (is.null(storage_backend)) {
    storage_backend <- get_default_storage()
  }

  # Get attempt count in time window
  current_time <- Sys.time()
  window_start <- current_time - time_window_seconds

  attempts <- get_attempts_in_window(
    session_id = session_id,
    start_time = window_start,
    end_time = current_time,
    storage_backend = storage_backend
  )

  attempts_count <- nrow(attempts)
  allowed <- attempts_count < max_attempts

  list(
    allowed = allowed,
    attempts_count = attempts_count,
    max_attempts = max_attempts,
    time_window_seconds = time_window_seconds,
    reset_time = if (!allowed) {
      min(attempts$timestamp) + time_window_seconds
    } else {
      NULL
    }
  )
}

#' Record Failed Attempt with Tracking
#'
#' Records a failed captcha attempt with metadata for analysis and security.
#'
#' @param captcha_id captcha identifier
#' @param session_id session or IP identifier
#' @param metadata additional metadata (user agent, etc.)
#' @param storage_backend storage backend
#'
#' @export
captcha_record_failure <- function(captcha_id,
                                   session_id = NULL,
                                   metadata = list(),
                                   storage_backend = NULL) {

  if (is.null(storage_backend)) {
    storage_backend <- get_default_storage()
  }

  record_attempt(
    captcha_id = captcha_id,
    session_id = session_id,
    success = FALSE,
    metadata = metadata,
    storage_backend = storage_backend
  )

  invisible(TRUE)
}

#' Get Captcha Statistics
#'
#' Retrieves statistics about captcha usage, success rates, and security metrics.
#'
#' @param time_window_seconds time window for statistics (default: 86400 = 24 hours)
#' @param storage_backend storage backend
#'
#' @return list of statistics including total attempts, success rate, avg solve time
#'
#' @examples
#' stats <- captcha_get_stats()
#' print(paste("Success rate:", stats$success_rate))
#'
#' @export
captcha_get_stats <- function(time_window_seconds = 86400,
                              storage_backend = NULL) {

  if (is.null(storage_backend)) {
    storage_backend <- get_default_storage()
  }

  current_time <- Sys.time()
  window_start <- current_time - time_window_seconds

  attempts <- get_attempts_in_window(
    start_time = window_start,
    end_time = current_time,
    storage_backend = storage_backend
  )

  if (nrow(attempts) == 0) {
    return(list(
      total_attempts = 0,
      successful_attempts = 0,
      failed_attempts = 0,
      success_rate = NA,
      avg_solve_time = NA,
      time_window_seconds = time_window_seconds
    ))
  }

  successful <- sum(attempts$success, na.rm = TRUE)
  failed <- sum(!attempts$success, na.rm = TRUE)

  list(
    total_attempts = nrow(attempts),
    successful_attempts = successful,
    failed_attempts = failed,
    success_rate = successful / nrow(attempts),
    avg_solve_time = mean(attempts$solve_time, na.rm = TRUE),
    time_window_seconds = time_window_seconds,
    unique_sessions = length(unique(attempts$session_id))
  )
}

# ============================================================================
# Internal helper functions
# ============================================================================

#' Get or Create Session Secret
#' @keywords internal
get_session_secret <- function() {
  secret_env_var <- "CAPTCHA_SECRET_KEY"

  # Check environment variable
  secret <- Sys.getenv(secret_env_var, unset = NA)

  if (is.na(secret)) {
    # Check session cache
    if (exists("captcha_session_secret", envir = .captcha_env)) {
      secret <- get("captcha_session_secret", envir = .captcha_env)
    } else {
      # Generate new secret for this session
      secret <- generate_secret_key()
      assign("captcha_session_secret", secret, envir = .captcha_env)
      warning(
        "No CAPTCHA_SECRET_KEY found. Using session secret. ",
        "Set CAPTCHA_SECRET_KEY environment variable for production use."
      )
    }
  }

  secret
}

#' Generate Secret Key
#' @keywords internal
generate_secret_key <- function() {
  paste(sample(c(letters, LETTERS, 0:9), 64, replace = TRUE), collapse = "")
}

#' Generate Nonce
#' @keywords internal
generate_nonce <- function() {
  paste(sample(c(letters, LETTERS, 0:9), 16, replace = TRUE), collapse = "")
}

#' Digest Answer with Secret
#' @keywords internal
digest_answer <- function(answer, secret) {
  # Simple hash using digest (would use a proper crypto library in production)
  answer_lower <- tolower(as.character(answer))
  raw_string <- paste0(answer_lower, secret)
  digest::digest(raw_string, algo = "sha256")
}

#' Serialize Payload
#' @keywords internal
serialize_payload <- function(payload) {
  json_str <- jsonlite::toJSON(payload, auto_unbox = TRUE)
  base64enc::base64encode(charToRaw(as.character(json_str)))
}

#' Deserialize Payload
#' @keywords internal
deserialize_payload <- function(payload_string) {
  json_str <- rawToChar(base64enc::base64decode(payload_string))
  jsonlite::fromJSON(json_str)
}

#' Sign Payload
#' @keywords internal
sign_payload <- function(payload_string, secret) {
  raw_string <- paste0(payload_string, secret)
  digest::digest(raw_string, algo = "sha256")
}

#' Get Default Storage Backend
#' @keywords internal
get_default_storage <- function() {
  if (!exists("captcha_storage", envir = .captcha_env)) {
    # Initialize in-memory storage
    storage <- list(
      attempts = data.frame(
        captcha_id = character(),
        session_id = character(),
        timestamp = as.POSIXct(character()),
        success = logical(),
        solve_time = numeric(),
        metadata = character(),
        stringsAsFactors = FALSE
      ),
      used_tokens = character()
    )
    assign("captcha_storage", storage, envir = .captcha_env)
  }

  get("captcha_storage", envir = .captcha_env)
}

#' Record Attempt
#' @keywords internal
record_attempt <- function(captcha_id,
                          session_id = "unknown",
                          success = FALSE,
                          solve_time = NA,
                          metadata = list(),
                          storage_backend) {

  new_row <- data.frame(
    captcha_id = captcha_id,
    session_id = session_id,
    timestamp = Sys.time(),
    success = success,
    solve_time = solve_time,
    metadata = jsonlite::toJSON(metadata, auto_unbox = TRUE),
    stringsAsFactors = FALSE
  )

  storage_backend$attempts <- rbind(storage_backend$attempts, new_row)

  # Update storage
  assign("captcha_storage", storage_backend, envir = .captcha_env)

  invisible(TRUE)
}

#' Get Attempts in Time Window
#' @keywords internal
get_attempts_in_window <- function(session_id = NULL,
                                   start_time,
                                   end_time,
                                   storage_backend) {

  attempts <- storage_backend$attempts

  # Filter by time window
  attempts <- attempts[attempts$timestamp >= start_time &
                      attempts$timestamp <= end_time, ]

  # Filter by session if provided
  if (!is.null(session_id)) {
    attempts <- attempts[attempts$session_id == session_id, ]
  }

  attempts
}

#' Check if Token is Used
#' @keywords internal
is_token_used <- function(captcha_id, storage_backend) {
  captcha_id %in% storage_backend$used_tokens
}

#' Mark Token as Used
#' @keywords internal
mark_token_used <- function(captcha_id, storage_backend) {
  storage_backend$used_tokens <- c(storage_backend$used_tokens, captcha_id)
  assign("captcha_storage", storage_backend, envir = .captcha_env)
  invisible(TRUE)
}

#' Initialize Captcha Environment
#' @keywords internal
.captcha_env <- new.env(parent = emptyenv())
