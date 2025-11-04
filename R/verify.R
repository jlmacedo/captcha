#' Multi-Modal Verification for Anti-AI Captcha
#'
#' Provides additional verification beyond simple answer checking,
#' including timing analysis, behavioral patterns, and progressive difficulty.

#' Verify Captcha with Multi-Modal Checks
#'
#' Performs comprehensive verification including timing analysis,
#' behavioral checks, and progressive difficulty assessment.
#'
#' @param token captcha token
#' @param answer user's answer
#' @param captcha_id captcha identifier
#' @param solve_time_seconds time taken to solve in seconds
#' @param session_id session or IP identifier
#' @param behavior_data optional behavioral data (mouse movements, etc.)
#' @param secret_key secret key for validation
#' @param strict_mode enable strict timing checks (default: TRUE)
#'
#' @return list with validation result and detailed feedback
#'
#' @examples
#' result <- captcha_verify_multimodal(
#'   token = token,
#'   answer = "abc123",
#'   captcha_id = "12345",
#'   solve_time_seconds = 8.5,
#'   session_id = "192.168.1.1"
#' )
#'
#' @export
captcha_verify_multimodal <- function(token,
                                      answer,
                                      captcha_id,
                                      solve_time_seconds,
                                      session_id = NULL,
                                      behavior_data = NULL,
                                      secret_key = NULL,
                                      strict_mode = TRUE) {

  # Initialize result
  result <- list(
    valid = FALSE,
    checks = list(),
    warnings = character(),
    risk_score = 0
  )

  # 1. Basic token validation
  token_result <- captcha_validate_token(
    token = token,
    answer = answer,
    captcha_id = captcha_id,
    secret_key = secret_key
  )

  result$checks$token_valid <- token_result$valid

  if (!token_result$valid) {
    result$message <- token_result$message
    result$error <- token_result$error
    return(result)
  }

  # 2. Timing analysis
  timing_result <- verify_timing(
    solve_time_seconds = solve_time_seconds,
    strict_mode = strict_mode
  )

  result$checks$timing <- timing_result
  result$risk_score <- result$risk_score + timing_result$risk_score

  if (!timing_result$valid && strict_mode) {
    result$message <- timing_result$message
    result$warnings <- c(result$warnings, timing_result$message)
  }

  # 3. Rate limiting check
  if (!is.null(session_id)) {
    rate_result <- captcha_check_rate_limit(session_id = session_id)
    result$checks$rate_limit <- rate_result

    if (!rate_result$allowed) {
      result$valid <- FALSE
      result$message <- paste(
        "Rate limit exceeded.",
        rate_result$attempts_count,
        "attempts in the last hour.",
        "Please try again later."
      )
      return(result)
    }
  }

  # 4. Behavioral analysis (if provided)
  if (!is.null(behavior_data)) {
    behavior_result <- verify_behavior(behavior_data)
    result$checks$behavior <- behavior_result
    result$risk_score <- result$risk_score + behavior_result$risk_score

    if (!behavior_result$valid) {
      result$warnings <- c(result$warnings, behavior_result$message)
    }
  }

  # 5. Session history analysis
  if (!is.null(session_id)) {
    history_result <- verify_session_history(session_id)
    result$checks$session_history <- history_result
    result$risk_score <- result$risk_score + history_result$risk_score

    if (history_result$suspicious) {
      result$warnings <- c(result$warnings, history_result$message)
    }
  }

  # Final determination
  if (strict_mode) {
    result$valid <- token_result$valid &&
                    timing_result$valid &&
                    result$risk_score < 50
  } else {
    result$valid <- token_result$valid &&
                    result$risk_score < 70
  }

  if (result$valid) {
    result$message <- "Verification successful"
  } else {
    result$message <- "Verification failed - suspicious activity detected"
  }

  result$captcha_id <- captcha_id
  result$solve_time <- solve_time_seconds
  result$risk_level <- categorize_risk_score(result$risk_score)

  result
}

#' Verify Solving Timing
#'
#' Checks if the solve time is within human-reasonable bounds.
#' Too fast suggests bot, too slow might indicate automated solving.
#'
#' @param solve_time_seconds time taken to solve
#' @param strict_mode enable strict checks
#'
#' @return list with timing verification result
#'
#' @keywords internal
verify_timing <- function(solve_time_seconds, strict_mode = TRUE) {

  # Define reasonable bounds for human solving
  min_time <- if (strict_mode) 2.0 else 1.0  # Minimum reasonable time
  max_time <- if (strict_mode) 60.0 else 120.0  # Maximum reasonable time
  optimal_min <- 5.0  # Optimal minimum (most humans take at least 5 seconds)
  optimal_max <- 30.0  # Optimal maximum (most humans solve within 30 seconds)

  risk_score <- 0
  valid <- TRUE
  message <- "Timing normal"

  if (solve_time_seconds < min_time) {
    risk_score <- 40
    valid <- FALSE
    message <- sprintf(
      "Suspiciously fast solve time (%.2f seconds). Possible bot activity.",
      solve_time_seconds
    )
  } else if (solve_time_seconds < optimal_min) {
    risk_score <- 20
    message <- sprintf(
      "Fast solve time (%.2f seconds). Flagged for review.",
      solve_time_seconds
    )
  } else if (solve_time_seconds > max_time) {
    risk_score <- 25
    valid <- !strict_mode
    message <- sprintf(
      "Very slow solve time (%.2f seconds). Possible automated solving.",
      solve_time_seconds
    )
  } else if (solve_time_seconds > optimal_max) {
    risk_score <- 10
    message <- sprintf(
      "Slow solve time (%.2f seconds).",
      solve_time_seconds
    )
  }

  list(
    valid = valid,
    solve_time = solve_time_seconds,
    within_bounds = solve_time_seconds >= min_time && solve_time_seconds <= max_time,
    optimal = solve_time_seconds >= optimal_min && solve_time_seconds <= optimal_max,
    risk_score = risk_score,
    message = message
  )
}

#' Verify Behavioral Patterns
#'
#' Analyzes behavioral data like mouse movements to detect bot activity.
#'
#' @param behavior_data list containing behavioral metrics
#'
#' @return list with behavior verification result
#'
#' @keywords internal
verify_behavior <- function(behavior_data) {

  risk_score <- 0
  valid <- TRUE
  message <- "Behavior patterns normal"

  # Check for mouse movement data
  if (!is.null(behavior_data$mouse_movements)) {
    movements <- behavior_data$mouse_movements

    # No mouse movements is suspicious
    if (length(movements) == 0) {
      risk_score <- risk_score + 30
      message <- "No mouse movements detected - possible bot"
      valid <- FALSE
    } else if (length(movements) < 5) {
      risk_score <- risk_score + 15
      message <- "Very few mouse movements - flagged for review"
    }

    # Check for too-perfect linear movements (bot-like)
    if (length(movements) > 0 && is_linear_movement(movements)) {
      risk_score <- risk_score + 20
      message <- "Suspiciously linear mouse movements"
    }
  }

  # Check for keyboard timing patterns
  if (!is.null(behavior_data$keypress_intervals)) {
    intervals <- behavior_data$keypress_intervals

    # Too-consistent typing speed is suspicious
    if (length(intervals) > 2) {
      interval_sd <- stats::sd(intervals)
      if (interval_sd < 0.05) {
        risk_score <- risk_score + 25
        message <- "Suspiciously consistent typing speed"
        valid <- FALSE
      }
    }
  }

  # Check for copy-paste behavior
  if (!is.null(behavior_data$paste_detected) && behavior_data$paste_detected) {
    risk_score <- risk_score + 15
    message <- "Paste action detected"
  }

  list(
    valid = valid,
    risk_score = risk_score,
    message = message,
    details = behavior_data
  )
}

#' Verify Session History
#'
#' Analyzes historical patterns from a session/IP to detect abuse.
#'
#' @param session_id session or IP identifier
#'
#' @return list with session history analysis
#'
#' @keywords internal
verify_session_history <- function(session_id) {

  storage <- get_default_storage()
  risk_score <- 0
  suspicious <- FALSE
  message <- "Session history normal"

  # Get recent attempts from this session
  window_start <- Sys.time() - 3600  # Last hour
  attempts <- get_attempts_in_window(
    session_id = session_id,
    start_time = window_start,
    end_time = Sys.time(),
    storage_backend = storage
  )

  if (nrow(attempts) == 0) {
    return(list(
      suspicious = FALSE,
      risk_score = 0,
      message = "No recent history",
      attempts_count = 0
    ))
  }

  attempts_count <- nrow(attempts)
  success_count <- sum(attempts$success, na.rm = TRUE)
  failure_count <- attempts_count - success_count

  # High volume of attempts is suspicious
  if (attempts_count > 20) {
    risk_score <- risk_score + 30
    suspicious <- TRUE
    message <- sprintf(
      "High volume of attempts (%d in last hour) - possible automated solving",
      attempts_count
    )
  } else if (attempts_count > 10) {
    risk_score <- risk_score + 15
    message <- sprintf("Elevated attempt volume (%d in last hour)", attempts_count)
  }

  # Very high success rate might indicate bot
  if (attempts_count > 5) {
    success_rate <- success_count / attempts_count
    if (success_rate > 0.95) {
      risk_score <- risk_score + 25
      suspicious <- TRUE
      message <- sprintf(
        "Unusually high success rate (%.1f%%) - possible bot",
        success_rate * 100
      )
    }
  }

  # Check for consistent solve times (bot-like behavior)
  if (attempts_count > 3) {
    solve_times <- attempts$solve_time[!is.na(attempts$solve_time)]
    if (length(solve_times) > 2) {
      solve_time_sd <- stats::sd(solve_times)
      mean_solve_time <- mean(solve_times)
      cv <- solve_time_sd / mean_solve_time  # Coefficient of variation

      if (cv < 0.15) {  # Very consistent
        risk_score <- risk_score + 20
        suspicious <- TRUE
        message <- "Suspiciously consistent solve times across attempts"
      }
    }
  }

  list(
    suspicious = suspicious,
    risk_score = risk_score,
    message = message,
    attempts_count = attempts_count,
    success_count = success_count,
    failure_count = failure_count,
    success_rate = if (attempts_count > 0) success_count / attempts_count else NA
  )
}

#' Check if Mouse Movements are Linear (Bot-like)
#'
#' @param movements list of (x, y) coordinates
#' @return TRUE if movements are suspiciously linear
#'
#' @keywords internal
is_linear_movement <- function(movements) {
  # Simplified check: if movements follow a too-perfect line, likely bot
  # In practice, this would use more sophisticated analysis

  if (length(movements) < 3) return(FALSE)

  # Extract x and y coordinates
  # Assuming movements is a list of lists like list(list(x=1, y=2), ...)
  if (is.list(movements[[1]])) {
    x_coords <- sapply(movements, function(m) m$x)
    y_coords <- sapply(movements, function(m) m$y)

    # Simple linearity check using correlation
    if (length(x_coords) > 2 && stats::sd(x_coords) > 0) {
      correlation <- stats::cor(x_coords, y_coords)
      # Perfect or near-perfect correlation is suspicious
      return(abs(correlation) > 0.98)
    }
  }

  FALSE
}

#' Categorize Risk Score
#'
#' @param risk_score numeric risk score
#' @return risk level category
#'
#' @keywords internal
categorize_risk_score <- function(risk_score) {
  if (risk_score < 20) {
    "low"
  } else if (risk_score < 40) {
    "medium"
  } else if (risk_score < 60) {
    "high"
  } else {
    "critical"
  }
}

#' Determine Next Captcha Difficulty
#'
#' Based on session history, determines appropriate difficulty for next captcha.
#' Progressive difficulty helps prevent automated solving.
#'
#' @param session_id session identifier
#'
#' @return recommended difficulty level
#'
#' @examples
#' difficulty <- captcha_progressive_difficulty("192.168.1.1")
#'
#' @export
captcha_progressive_difficulty <- function(session_id) {

  storage <- get_default_storage()

  # Get recent attempts
  window_start <- Sys.time() - 3600
  attempts <- get_attempts_in_window(
    session_id = session_id,
    start_time = window_start,
    end_time = Sys.time(),
    storage_backend = storage
  )

  if (nrow(attempts) == 0) {
    return("medium")  # Default to medium for new sessions
  }

  failure_count <- sum(!attempts$success, na.rm = TRUE)
  total_count <- nrow(attempts)

  # Increase difficulty based on failure count
  if (failure_count >= 5) {
    "extreme"  # Many failures: use extreme difficulty
  } else if (failure_count >= 3) {
    "hard"  # Some failures: use hard
  } else if (total_count > 10) {
    "hard"  # High volume: increase difficulty
  } else if (failure_count >= 1) {
    "medium"  # Few failures: stay medium
  } else {
    "medium"  # Default
  }
}

#' Generate Verification Report
#'
#' Creates a detailed report of verification checks for logging/auditing.
#'
#' @param verification_result result from captcha_verify_multimodal
#'
#' @return formatted text report
#'
#' @export
captcha_verification_report <- function(verification_result) {

  report <- c(
    "=== Captcha Verification Report ===",
    sprintf("Captcha ID: %s", verification_result$captcha_id),
    sprintf("Valid: %s", verification_result$valid),
    sprintf("Risk Score: %d (%s)",
            verification_result$risk_score,
            verification_result$risk_level),
    "",
    "Checks:",
    sprintf("  - Token Valid: %s", verification_result$checks$token_valid),
    sprintf("  - Timing: %s (%.2f seconds)",
            verification_result$checks$timing$valid,
            verification_result$checks$timing$solve_time),
    ""
  )

  if (!is.null(verification_result$checks$behavior)) {
    report <- c(report,
      sprintf("  - Behavior: %s", verification_result$checks$behavior$valid)
    )
  }

  if (!is.null(verification_result$checks$session_history)) {
    report <- c(report,
      sprintf("  - Session History: %d attempts",
              verification_result$checks$session_history$attempts_count)
    )
  }

  if (length(verification_result$warnings) > 0) {
    report <- c(report,
      "",
      "Warnings:",
      paste("  -", verification_result$warnings)
    )
  }

  report <- c(report,
    "",
    sprintf("Message: %s", verification_result$message),
    "===================================="
  )

  paste(report, collapse = "\n")
}
