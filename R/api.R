#' Professional Anti-AI Captcha API
#'
#' High-level API for generating, validating, and managing anti-AI resistant captchas.
#' This API provides a complete, production-ready interface with security features.

#' Create a New Anti-AI Captcha Challenge
#'
#' Generates a secure captcha with token and returns all necessary data
#' for client-side display and server-side validation.
#'
#' @param difficulty difficulty level: "easy", "medium", "hard", "extreme"
#' @param session_id optional session/IP identifier for rate limiting
#' @param use_progressive_difficulty automatically adjust difficulty based on session history
#' @param expiry_seconds token validity period (default: 300 = 5 minutes)
#' @param include_semantic include semantic elements (default: TRUE)
#' @param adversarial_noise include adversarial noise (default: TRUE)
#' @param secret_key optional secret key (uses session key if NULL)
#'
#' @return list containing:
#'   - `image`: the captcha image (magick object)
#'   - `token`: validation token (send to client)
#'   - `captcha_id`: unique identifier
#'   - `expires_at`: expiration timestamp
#'   - `difficulty`: difficulty level used
#'
#' @examples
#' # Create a hard difficulty captcha
#' challenge <- captcha_create_challenge(difficulty = "hard")
#' plot(challenge$image)
#'
#' # Create with progressive difficulty based on session
#' challenge <- captcha_create_challenge(
#'   session_id = "192.168.1.1",
#'   use_progressive_difficulty = TRUE
#' )
#'
#' @export
captcha_create_challenge <- function(difficulty = "hard",
                                     session_id = NULL,
                                     use_progressive_difficulty = FALSE,
                                     expiry_seconds = 300,
                                     include_semantic = TRUE,
                                     adversarial_noise = TRUE,
                                     secret_key = NULL) {

  # Check rate limiting first
  if (!is.null(session_id)) {
    rate_check <- captcha_check_rate_limit(session_id = session_id)
    if (!rate_check$allowed) {
      stop(sprintf(
        "Rate limit exceeded: %d/%d attempts. Try again after %s",
        rate_check$attempts_count,
        rate_check$max_attempts,
        format(rate_check$reset_time, "%H:%M:%S")
      ))
    }
  }

  # Determine difficulty
  if (use_progressive_difficulty && !is.null(session_id)) {
    difficulty <- captcha_progressive_difficulty(session_id)
  }

  # Generate secure captcha
  captcha <- captcha_generate_secure(
    difficulty = difficulty,
    include_semantic = include_semantic,
    adversarial_noise = adversarial_noise
  )

  # Generate validation token
  token_data <- captcha_generate_token(
    captcha_id = captcha$id,
    answer = captcha$lab,
    expiry_seconds = expiry_seconds,
    secret_key = secret_key
  )

  # Return challenge data
  list(
    image = captcha$img,
    token = token_data$token,
    captcha_id = captcha$id,
    difficulty = difficulty,
    expires_at = as.POSIXct(token_data$expiry, origin = "1970-01-01"),
    expires_in_seconds = expiry_seconds,
    timestamp = Sys.time()
  )
}

#' Verify Captcha Solution
#'
#' Validates a captcha solution with comprehensive security checks including
#' token validation, timing analysis, rate limiting, and behavioral verification.
#'
#' @param token validation token from challenge
#' @param answer user's submitted answer
#' @param captcha_id captcha identifier from challenge
#' @param solve_time_seconds time taken to solve (in seconds)
#' @param session_id session/IP identifier (recommended)
#' @param behavior_data optional behavioral data (mouse movements, keypress timing)
#' @param strict_mode enable strict verification (default: TRUE)
#' @param secret_key optional secret key
#'
#' @return list containing:
#'   - `valid`: TRUE if captcha solved correctly and passed all checks
#'   - `message`: human-readable result message
#'   - `risk_score`: calculated risk score (0-100)
#'   - `risk_level`: risk category ("low", "medium", "high", "critical")
#'   - `checks`: detailed results of all verification checks
#'   - `warnings`: any warnings flagged during verification
#'
#' @examples
#' # Create challenge
#' challenge <- captcha_create_challenge()
#'
#' # Later, verify solution
#' result <- captcha_verify_solution(
#'   token = challenge$token,
#'   answer = "abc123",
#'   captcha_id = challenge$captcha_id,
#'   solve_time_seconds = 8.5,
#'   session_id = "192.168.1.1"
#' )
#'
#' if (result$valid) {
#'   print("Access granted!")
#' } else {
#'   print(paste("Verification failed:", result$message))
#' }
#'
#' @export
captcha_verify_solution <- function(token,
                                    answer,
                                    captcha_id,
                                    solve_time_seconds,
                                    session_id = NULL,
                                    behavior_data = NULL,
                                    strict_mode = TRUE,
                                    secret_key = NULL) {

  # Perform multi-modal verification
  result <- captcha_verify_multimodal(
    token = token,
    answer = answer,
    captcha_id = captcha_id,
    solve_time_seconds = solve_time_seconds,
    session_id = session_id,
    behavior_data = behavior_data,
    secret_key = secret_key,
    strict_mode = strict_mode
  )

  # Log verification attempt
  if (!is.null(session_id)) {
    if (!result$valid) {
      captcha_record_failure(
        captcha_id = captcha_id,
        session_id = session_id,
        metadata = list(
          risk_score = result$risk_score,
          risk_level = result$risk_level,
          solve_time = solve_time_seconds,
          warnings = result$warnings
        )
      )
    }
  }

  result
}

#' Complete Captcha Workflow: Create, Display, Verify
#'
#' Convenience function that handles the complete captcha workflow
#' in interactive sessions. Useful for testing and development.
#'
#' @param difficulty difficulty level
#' @param interactive if TRUE, prompts user to solve (default: TRUE)
#' @param session_id optional session identifier
#'
#' @return verification result (if interactive) or challenge data (if not interactive)
#'
#' @examples
#' \dontrun{
#' # Interactive mode: generates, displays, and prompts for solution
#' result <- captcha_complete_workflow(difficulty = "medium")
#'
#' # Non-interactive: just creates challenge
#' challenge <- captcha_complete_workflow(interactive = FALSE)
#' }
#'
#' @export
captcha_complete_workflow <- function(difficulty = "medium",
                                      interactive = TRUE,
                                      session_id = "test_session") {

  # Create challenge
  message("Creating anti-AI captcha challenge...")
  challenge <- captcha_create_challenge(
    difficulty = difficulty,
    session_id = session_id
  )

  message(sprintf("Difficulty: %s", challenge$difficulty))
  message(sprintf("Captcha ID: %s", challenge$captcha_id))
  message(sprintf("Expires: %s", format(challenge$expires_at, "%H:%M:%S")))

  # Display image
  if (interactive) {
    plot(challenge$image)

    # Prompt for answer
    start_time <- Sys.time()
    answer <- readline(prompt = "Enter captcha text: ")
    end_time <- Sys.time()
    solve_time <- as.numeric(difftime(end_time, start_time, units = "secs"))

    # Verify
    message("\nVerifying solution...")
    result <- captcha_verify_solution(
      token = challenge$token,
      answer = answer,
      captcha_id = challenge$captcha_id,
      solve_time_seconds = solve_time,
      session_id = session_id,
      strict_mode = TRUE
    )

    # Display results
    message("\n=== Verification Result ===")
    message(sprintf("Valid: %s", result$valid))
    message(sprintf("Message: %s", result$message))
    message(sprintf("Risk Score: %d (%s)", result$risk_score, result$risk_level))
    message(sprintf("Solve Time: %.2f seconds", solve_time))

    if (length(result$warnings) > 0) {
      message("\nWarnings:")
      for (warning in result$warnings) {
        message(sprintf("  - %s", warning))
      }
    }

    if (result$valid) {
      message("\n✓ Captcha solved successfully!")
    } else {
      message("\n✗ Captcha verification failed!")
    }

    return(result)
  } else {
    return(challenge)
  }
}

#' Export Captcha as File with Token
#'
#' Saves captcha image to disk with accompanying metadata file containing
#' the validation token and challenge details.
#'
#' @param challenge challenge object from captcha_create_challenge
#' @param path directory to save files
#' @param format image format ("png", "jpeg", "gif")
#' @param include_metadata save metadata JSON file
#'
#' @return list with paths to saved files
#'
#' @examples
#' challenge <- captcha_create_challenge()
#' files <- captcha_export_challenge(challenge, path = tempdir())
#'
#' @export
captcha_export_challenge <- function(challenge,
                                     path = getwd(),
                                     format = "png",
                                     include_metadata = TRUE) {

  dir.create(path, showWarnings = FALSE, recursive = TRUE)

  # Generate filename
  base_name <- sprintf("captcha_%s", challenge$captcha_id)
  image_file <- file.path(path, sprintf("%s.%s", base_name, format))

  # Save image
  magick::image_write(challenge$image, image_file, format = format)

  result <- list(image_file = image_file)

  # Save metadata
  if (include_metadata) {
    metadata_file <- file.path(path, sprintf("%s_metadata.json", base_name))

    metadata <- list(
      captcha_id = challenge$captcha_id,
      token = challenge$token,
      difficulty = challenge$difficulty,
      expires_at = format(challenge$expires_at, "%Y-%m-%d %H:%M:%S"),
      timestamp = format(challenge$timestamp, "%Y-%m-%d %H:%M:%S"),
      image_file = basename(image_file)
    )

    jsonlite::write_json(metadata, metadata_file, pretty = TRUE, auto_unbox = TRUE)
    result$metadata_file <- metadata_file
  }

  message(sprintf("Captcha exported to: %s", path))
  invisible(result)
}

#' Batch Generate Captcha Dataset
#'
#' Generates multiple captchas for testing, training, or dataset creation.
#' Useful for security testing and AI resistance evaluation.
#'
#' @param n number of captchas to generate
#' @param difficulties vector of difficulty levels to sample from
#' @param path directory to save captchas
#' @param include_metadata save metadata for each captcha
#'
#' @return data frame with information about generated captchas
#'
#' @examples
#' # Generate 10 captchas with varying difficulty
#' dataset <- captcha_batch_generate(
#'   n = 10,
#'   difficulties = c("medium", "hard", "extreme"),
#'   path = tempdir()
#' )
#'
#' @export
captcha_batch_generate <- function(n = 10,
                                   difficulties = c("easy", "medium", "hard", "extreme"),
                                   path = getwd(),
                                   include_metadata = TRUE) {

  message(sprintf("Generating %d anti-AI captchas...", n))

  results <- list()

  for (i in 1:n) {
    # Random difficulty
    difficulty <- sample(difficulties, 1)

    # Generate challenge
    challenge <- captcha_create_challenge(difficulty = difficulty)

    # Export
    files <- captcha_export_challenge(
      challenge = challenge,
      path = path,
      include_metadata = include_metadata
    )

    results[[i]] <- list(
      index = i,
      captcha_id = challenge$captcha_id,
      difficulty = challenge$difficulty,
      image_file = files$image_file,
      metadata_file = if (include_metadata) files$metadata_file else NA
    )

    if (i %% 10 == 0) {
      message(sprintf("  Generated %d/%d...", i, n))
    }
  }

  # Convert to data frame
  results_df <- do.call(rbind, lapply(results, as.data.frame))

  message(sprintf("✓ Generated %d captchas in: %s", n, path))

  results_df
}

#' Get System Status and Statistics
#'
#' Returns comprehensive statistics about the captcha system including
#' usage metrics, security stats, and system health.
#'
#' @param time_window_seconds time window for statistics (default: 86400 = 24 hours)
#'
#' @return list with system statistics
#'
#' @examples
#' status <- captcha_system_status()
#' print(status$summary)
#'
#' @export
captcha_system_status <- function(time_window_seconds = 86400) {

  stats <- captcha_get_stats(time_window_seconds = time_window_seconds)

  summary_text <- sprintf(
    "Captcha System Status (Last %d hours):\n  Total Attempts: %d\n  Successful: %d\n  Failed: %d\n  Success Rate: %.1f%%\n  Avg Solve Time: %.2f seconds\n  Unique Sessions: %d",
    time_window_seconds / 3600,
    stats$total_attempts,
    stats$successful_attempts,
    stats$failed_attempts,
    ifelse(is.na(stats$success_rate), 0, stats$success_rate * 100),
    ifelse(is.na(stats$avg_solve_time), 0, stats$avg_solve_time),
    ifelse(is.null(stats$unique_sessions), 0, stats$unique_sessions)
  )

  list(
    stats = stats,
    summary = summary_text,
    healthy = stats$total_attempts == 0 ||
              (!is.na(stats$success_rate) && stats$success_rate > 0.05),
    timestamp = Sys.time()
  )
}

#' Reset Captcha System Storage
#'
#' Clears all stored attempts and used tokens. Use with caution!
#' Primarily for testing and development.
#'
#' @param confirm must be TRUE to actually reset
#'
#' @export
captcha_reset_storage <- function(confirm = FALSE) {
  if (!confirm) {
    message("Set confirm=TRUE to actually reset storage")
    return(invisible(FALSE))
  }

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

  message("✓ Storage reset successfully")
  invisible(TRUE)
}

#' Configure Captcha System
#'
#' Sets global configuration options for the captcha system.
#'
#' @param secret_key secret key for token signing (stored as environment variable)
#' @param default_difficulty default difficulty level
#' @param default_expiry default token expiry in seconds
#'
#' @export
captcha_configure <- function(secret_key = NULL,
                              default_difficulty = NULL,
                              default_expiry = NULL) {

  if (!is.null(secret_key)) {
    Sys.setenv(CAPTCHA_SECRET_KEY = secret_key)
    message("✓ Secret key configured")
  }

  if (!is.null(default_difficulty)) {
    assign("captcha_default_difficulty", default_difficulty, envir = .captcha_env)
    message(sprintf("✓ Default difficulty set to: %s", default_difficulty))
  }

  if (!is.null(default_expiry)) {
    assign("captcha_default_expiry", default_expiry, envir = .captcha_env)
    message(sprintf("✓ Default expiry set to: %d seconds", default_expiry))
  }

  invisible(TRUE)
}
