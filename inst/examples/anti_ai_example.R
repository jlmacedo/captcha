# ============================================================================
# Professional Anti-AI Captcha Examples
# ============================================================================
#
# This file demonstrates how to use the anti-AI resistant captcha system
# with complete security features including token validation, rate limiting,
# and multi-modal verification.

library(captcha)

# ============================================================================
# BASIC USAGE: Simple Challenge Creation and Verification
# ============================================================================

# 1. Create a captcha challenge
challenge <- captcha_create_challenge(difficulty = "hard")

# Display the captcha
plot(challenge$image)

# Challenge contains:
# - image: the captcha image
# - token: validation token (send to client)
# - captcha_id: unique identifier
# - expires_at: expiration time
print(challenge$captcha_id)
print(challenge$difficulty)

# 2. Verify a solution (simulating user submission)
result <- captcha_verify_solution(
  token = challenge$token,
  answer = "your_answer_here",  # User's answer
  captcha_id = challenge$captcha_id,
  solve_time_seconds = 8.5,  # Time taken to solve
  session_id = "192.168.1.1"  # IP address or session ID
)

# Check result
if (result$valid) {
  print("✓ Captcha solved correctly!")
} else {
  print(paste("✗ Verification failed:", result$message))
}

# ============================================================================
# INTERACTIVE WORKFLOW: Complete Testing
# ============================================================================

# This will display a captcha and prompt you to solve it
result <- captcha_complete_workflow(
  difficulty = "medium",
  interactive = TRUE,
  session_id = "test_session"
)

# ============================================================================
# DIFFICULTY LEVELS
# ============================================================================

# Generate captchas with different difficulty levels
difficulties <- c("easy", "medium", "hard", "extreme")

par(mfrow = c(2, 2))
for (diff in difficulties) {
  challenge <- captcha_create_challenge(difficulty = diff)
  plot(challenge$image, main = paste("Difficulty:", diff))
}
par(mfrow = c(1, 1))

# ============================================================================
# PROGRESSIVE DIFFICULTY: Adaptive Challenge
# ============================================================================

# Progressive difficulty automatically increases based on session history
challenge <- captcha_create_challenge(
  session_id = "192.168.1.1",
  use_progressive_difficulty = TRUE  # Adapts to failed attempts
)

# Check recommended difficulty for a session
recommended <- captcha_progressive_difficulty("192.168.1.1")
print(paste("Recommended difficulty:", recommended))

# ============================================================================
# ADVANCED CONFIGURATION
# ============================================================================

# Configure system with custom settings
captcha_configure(
  secret_key = "your_secret_key_here_64_chars_recommended",
  default_difficulty = "hard",
  default_expiry = 300  # 5 minutes
)

# Create challenge with custom settings
challenge <- captcha_create_challenge(
  difficulty = "extreme",
  expiry_seconds = 600,  # 10 minute expiry
  include_semantic = TRUE,  # Add semantic elements
  adversarial_noise = TRUE  # Add adversarial noise
)

# ============================================================================
# RATE LIMITING
# ============================================================================

# Check rate limits for a session
rate_status <- captcha_check_rate_limit(
  session_id = "192.168.1.1",
  max_attempts = 10,
  time_window_seconds = 3600  # 1 hour
)

if (rate_status$allowed) {
  print("Rate limit OK - can create captcha")
} else {
  print(paste(
    "Rate limit exceeded:",
    rate_status$attempts_count, "/", rate_status$max_attempts
  ))
}

# ============================================================================
# BEHAVIORAL VERIFICATION
# ============================================================================

# Verify with behavioral data
behavior_data <- list(
  mouse_movements = list(
    list(x = 10, y = 20),
    list(x = 15, y = 25),
    list(x = 22, y = 30)
  ),
  keypress_intervals = c(0.3, 0.25, 0.4, 0.35),  # seconds between keypresses
  paste_detected = FALSE
)

result <- captcha_verify_solution(
  token = challenge$token,
  answer = "answer",
  captcha_id = challenge$captcha_id,
  solve_time_seconds = 8.5,
  session_id = "192.168.1.1",
  behavior_data = behavior_data,
  strict_mode = TRUE
)

# Check risk assessment
print(paste("Risk Score:", result$risk_score))
print(paste("Risk Level:", result$risk_level))
print("Warnings:")
print(result$warnings)

# ============================================================================
# VERIFICATION REPORT
# ============================================================================

# Generate detailed verification report
report <- captcha_verification_report(result)
cat(report)

# ============================================================================
# EXPORTING CAPTCHAS
# ============================================================================

# Export a single captcha with metadata
challenge <- captcha_create_challenge(difficulty = "hard")
files <- captcha_export_challenge(
  challenge = challenge,
  path = tempdir(),
  format = "png",
  include_metadata = TRUE
)

print(files$image_file)
print(files$metadata_file)

# ============================================================================
# BATCH GENERATION
# ============================================================================

# Generate multiple captchas for testing
dataset <- captcha_batch_generate(
  n = 20,
  difficulties = c("medium", "hard", "extreme"),
  path = file.path(tempdir(), "captcha_dataset"),
  include_metadata = TRUE
)

# View dataset info
print(dataset)

# ============================================================================
# SYSTEM MONITORING
# ============================================================================

# Get system statistics
status <- captcha_system_status(time_window_seconds = 86400)  # Last 24 hours
cat(status$summary)

# Detailed stats
print(status$stats)

# ============================================================================
# TOKEN OPERATIONS
# ============================================================================

# Manual token generation (advanced use)
token_data <- captcha_generate_token(
  captcha_id = "custom_id_123",
  answer = "abc123",
  expiry_seconds = 300
)

print(token_data$token)
print(token_data$expiry)

# Manual token validation (advanced use)
validation <- captcha_validate_token(
  token = token_data$token,
  answer = "abc123",
  captcha_id = "custom_id_123"
)

print(validation$valid)
print(validation$message)

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Handle expired tokens
challenge <- captcha_create_challenge(expiry_seconds = 1)
Sys.sleep(2)  # Wait for expiry

result <- captcha_verify_solution(
  token = challenge$token,
  answer = "test",
  captcha_id = challenge$captcha_id,
  solve_time_seconds = 5
)

# Result will show: TOKEN_EXPIRED
print(result$error)
print(result$message)

# Handle rate limiting
tryCatch({
  # Simulate many attempts
  for (i in 1:15) {
    challenge <- captcha_create_challenge(session_id = "heavy_user")
  }
}, error = function(e) {
  print(paste("Rate limit error:", e$message))
})

# ============================================================================
# PRODUCTION DEPLOYMENT EXAMPLE
# ============================================================================

#' Production Captcha Endpoint Handler
#'
#' Example function showing how to integrate into web application
production_captcha_handler <- function(action, data) {

  if (action == "create") {
    # Client requests new captcha
    session_id <- data$session_id
    ip_address <- data$ip_address

    # Create challenge
    challenge <- captcha_create_challenge(
      session_id = ip_address,
      use_progressive_difficulty = TRUE,
      difficulty = "hard",
      expiry_seconds = 300
    )

    # Return to client (JSON response)
    return(list(
      success = TRUE,
      captcha_id = challenge$captcha_id,
      token = challenge$token,
      image_base64 = magick::image_write(challenge$image, format = "png") |>
        base64enc::base64encode(),
      expires_at = format(challenge$expires_at, "%Y-%m-%d %H:%M:%S"),
      difficulty = challenge$difficulty
    ))

  } else if (action == "verify") {
    # Client submits solution
    result <- captcha_verify_solution(
      token = data$token,
      answer = data$answer,
      captcha_id = data$captcha_id,
      solve_time_seconds = data$solve_time,
      session_id = data$ip_address,
      behavior_data = data$behavior_data,
      strict_mode = TRUE
    )

    # Return verification result
    return(list(
      success = result$valid,
      message = result$message,
      risk_score = result$risk_score,
      risk_level = result$risk_level
    ))
  }
}

# Example usage
# Create captcha
create_response <- production_captcha_handler(
  action = "create",
  data = list(
    session_id = "session_abc123",
    ip_address = "192.168.1.100"
  )
)

# Verify captcha
verify_response <- production_captcha_handler(
  action = "verify",
  data = list(
    token = create_response$token,
    answer = "user_answer",
    captcha_id = create_response$captcha_id,
    solve_time = 8.5,
    ip_address = "192.168.1.100",
    behavior_data = NULL
  )
)

# ============================================================================
# CLEANUP (for testing)
# ============================================================================

# Reset storage (WARNING: clears all data)
# captcha_reset_storage(confirm = TRUE)

# ============================================================================
# SECURITY BEST PRACTICES
# ============================================================================

# 1. Always set CAPTCHA_SECRET_KEY environment variable in production
#    Sys.setenv(CAPTCHA_SECRET_KEY = "your_64_character_secret_key")

# 2. Use HTTPS for all captcha endpoints to prevent token interception

# 3. Track session_id (IP address + session) for rate limiting

# 4. Use strict_mode = TRUE in production for maximum security

# 5. Monitor system status regularly
#    status <- captcha_system_status()
#    if (!status$healthy) { alert_admin() }

# 6. Set appropriate expiry times (300-600 seconds recommended)

# 7. Enable progressive difficulty for repeat offenders

# 8. Log all failed verification attempts for analysis

# 9. Use behavioral data when available (mouse, timing, etc.)

# 10. Implement exponential backoff for rate-limited sessions

print("✓ Anti-AI Captcha examples completed!")
