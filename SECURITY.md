# Security Policy

## 🛡️ Anti-AI Captcha Security Features

This document outlines the security features, best practices, and guidelines for using the captcha package's professional anti-AI resistant captcha system.

## Overview

The captcha package provides enterprise-grade security features designed to prevent automated solving by AI systems while remaining accessible to humans. The system includes multiple layers of defense:

1. **Cryptographic Token Validation**
2. **Rate Limiting & Abuse Prevention**
3. **Multi-Modal Verification**
4. **Behavioral Analysis**
5. **Progressive Difficulty Scaling**
6. **Risk Scoring & Monitoring**

## Security Architecture

### Token-Based Authentication

All captcha challenges generate cryptographically signed tokens that:
- Contain SHA-256 signatures to prevent tampering
- Include expiration timestamps (default: 5 minutes)
- Hash answers securely (never store plaintext)
- Enforce one-time use (tokens cannot be reused)
- Bind to specific captcha IDs

**Best Practice:**
```r
# Set a secure secret key in production
Sys.setenv(CAPTCHA_SECRET_KEY = "your_64_character_random_secret_key")

# Or configure programmatically
captcha_configure(secret_key = "your_secret_key_here")
```

⚠️ **Never commit secret keys to version control!**

### Rate Limiting

The system tracks attempts per session/IP address to prevent brute force attacks:

- Default: 10 attempts per hour
- Customizable time windows
- Automatic blocking of excessive attempts
- Session-based tracking

**Implementation:**
```r
# Check rate limits before creating challenge
rate_check <- captcha_check_rate_limit(
  session_id = user_ip_address,
  max_attempts = 10,
  time_window_seconds = 3600
)

if (!rate_check$allowed) {
  # Return 429 Too Many Requests
  stop("Rate limit exceeded")
}
```

### Multi-Modal Verification

The verification system analyzes multiple signals:

#### 1. Timing Analysis
- **Too Fast (<2s)**: Likely automated
- **Optimal (5-30s)**: Human range
- **Too Slow (>60s)**: Possible automated solving

#### 2. Behavioral Patterns
- Mouse movement analysis
- Keystroke timing patterns
- Copy-paste detection
- Linear movement detection (bot-like)

#### 3. Session History
- Success rate tracking
- Attempt frequency monitoring
- Solve time consistency analysis

**Example:**
```r
result <- captcha_verify_solution(
  token = token,
  answer = answer,
  captcha_id = captcha_id,
  solve_time_seconds = 8.5,
  session_id = user_ip,
  behavior_data = list(
    mouse_movements = mouse_coords,
    keypress_intervals = typing_times
  ),
  strict_mode = TRUE  # Enable all checks
)

# Check risk assessment
if (result$risk_score > 50) {
  # High risk - additional verification needed
  require_additional_verification()
}
```

## Anti-AI Techniques

### Adversarial Distortions

The system employs multiple distortion techniques specifically designed to resist AI:

1. **Frequency-Domain Noise**: Noise patterns that fool CNNs but remain invisible to humans
2. **3D Transforms**: Perspective distortions, shearing, warping
3. **Variable Spacing**: Unpredictable character positioning
4. **Dynamic Occlusion**: Crossing lines that force contextual inference
5. **Semantic Elements**: Arrows, shapes providing human-interpretable context

### Difficulty Levels

Choose appropriate difficulty based on security requirements:

| Level | Security | Human UX | Use Case |
|-------|----------|----------|----------|
| Easy | Low | Excellent | Contact forms, comments |
| Medium | Moderate | Good | Registration, login |
| Hard | High | Acceptable | Sensitive operations |
| Extreme | Maximum | Challenging | High-value transactions |

### Progressive Difficulty

Automatically increases complexity based on session behavior:

```r
challenge <- captcha_create_challenge(
  session_id = user_ip,
  use_progressive_difficulty = TRUE  # Adapts to failed attempts
)
```

**Logic:**
- 0-1 failures: Medium difficulty
- 2-4 failures: Hard difficulty
- 5+ failures: Extreme difficulty
- High volume (>10 attempts): Hard difficulty

## Production Deployment

### Environment Configuration

```r
# Production setup
Sys.setenv(CAPTCHA_SECRET_KEY = Sys.getenv("SECRET_KEY_FROM_ENV"))

captcha_configure(
  secret_key = Sys.getenv("CAPTCHA_SECRET_KEY"),
  default_difficulty = "hard",
  default_expiry = 300  # 5 minutes
)
```

### Endpoint Security

#### Create Challenge Endpoint

```r
create_captcha_handler <- function(request) {
  # 1. Extract session identifier
  session_id <- paste(request$ip, request$session_id, sep = "_")

  # 2. Check rate limits
  rate_check <- captcha_check_rate_limit(session_id)
  if (!rate_check$allowed) {
    return(http_response(429, "Rate limit exceeded"))
  }

  # 3. Generate challenge
  challenge <- captcha_create_challenge(
    session_id = session_id,
    use_progressive_difficulty = TRUE,
    difficulty = "hard"
  )

  # 4. Return response (send token to client)
  return(list(
    captcha_id = challenge$captcha_id,
    token = challenge$token,
    image = base64_encode_image(challenge$image),
    expires_at = challenge$expires_at
  ))
}
```

#### Verify Solution Endpoint

```r
verify_captcha_handler <- function(request) {
  # 1. Extract data
  session_id <- paste(request$ip, request$session_id, sep = "_")

  # 2. Verify solution
  result <- captcha_verify_solution(
    token = request$body$token,
    answer = request$body$answer,
    captcha_id = request$body$captcha_id,
    solve_time_seconds = request$body$solve_time,
    session_id = session_id,
    behavior_data = request$body$behavior_data,
    strict_mode = TRUE
  )

  # 3. Log result
  log_verification(session_id, result)

  # 4. Handle high-risk attempts
  if (result$risk_score > 70) {
    # Alert security team
    alert_security_team(session_id, result)
  }

  # 5. Return response
  return(list(
    valid = result$valid,
    message = result$message
  ))
}
```

### HTTPS Requirement

⚠️ **Always use HTTPS in production** to prevent:
- Token interception
- Man-in-the-middle attacks
- Answer eavesdropping

### Session Management

Best practices for session tracking:

```r
# Combine IP + session for robust tracking
session_id <- digest::digest(paste(
  request$ip_address,
  request$session_id,
  request$user_agent
), algo = "sha256")
```

## Monitoring & Analytics

### System Health Monitoring

```r
# Check system status regularly
status <- captcha_system_status(time_window_seconds = 86400)

if (!status$healthy) {
  # System may be under attack
  alert_admin()
}

# Monitor key metrics
if (status$stats$success_rate < 0.05) {
  # Too many failures - possible attack
  increase_difficulty()
}

if (status$stats$success_rate > 0.95) {
  # Too many successes - possible bypass
  investigate_sessions()
}
```

### Logging

Log all verification attempts for analysis:

```r
log_verification <- function(session_id, result) {
  log_entry <- list(
    timestamp = Sys.time(),
    session_id = session_id,
    captcha_id = result$captcha_id,
    valid = result$valid,
    risk_score = result$risk_score,
    risk_level = result$risk_level,
    solve_time = result$solve_time,
    warnings = result$warnings
  )

  # Write to log file or database
  write_log(log_entry)

  # Alert on high-risk attempts
  if (result$risk_level == "critical") {
    send_alert(log_entry)
  }
}
```

## Security Best Practices

### 1. Secret Key Management
- ✅ Use 64+ character random keys
- ✅ Store in environment variables
- ✅ Rotate keys periodically
- ❌ Never commit keys to Git
- ❌ Never hardcode keys

### 2. Token Security
- ✅ Use short expiry times (5-10 minutes)
- ✅ Enforce one-time use
- ✅ Validate all token fields
- ❌ Don't reuse tokens
- ❌ Don't extend expired tokens

### 3. Rate Limiting
- ✅ Track by IP + session
- ✅ Use exponential backoff
- ✅ Monitor for distributed attacks
- ✅ Implement CAPTCHA walls for repeated failures

### 4. Verification
- ✅ Always use strict_mode in production
- ✅ Collect behavioral data when possible
- ✅ Monitor risk scores
- ✅ Implement progressive difficulty

### 5. Monitoring
- ✅ Log all verification attempts
- ✅ Alert on unusual patterns
- ✅ Review statistics regularly
- ✅ Track session abuse

### 6. Network Security
- ✅ Use HTTPS only
- ✅ Implement CORS properly
- ✅ Validate request origins
- ✅ Use CSP headers

## Attack Vectors & Mitigations

### 1. Brute Force
**Attack**: Automated submission of many attempts
**Mitigation**: Rate limiting (10/hour), progressive difficulty, IP blocking

### 2. Neural Network Solving
**Attack**: AI models trained to solve captchas
**Mitigation**: Adversarial distortions, frequency-domain noise, semantic elements

### 3. Token Replay
**Attack**: Reusing valid tokens
**Mitigation**: One-time use enforcement, short expiry

### 4. Token Tampering
**Attack**: Modifying token contents
**Mitigation**: Cryptographic signatures (SHA-256)

### 5. Timing Attacks
**Attack**: Solving too fast (bots) or too slow (automated services)
**Mitigation**: Timing analysis, risk scoring

### 6. Distributed Attacks
**Attack**: Using multiple IPs to bypass rate limits
**Mitigation**: Session history analysis, pattern detection, global rate limits

### 7. Human Farms
**Attack**: Using human solvers
**Mitigation**: Behavioral analysis, solve time consistency, progressive difficulty

## Incident Response

### Suspected Bypass

If you suspect captcha bypass:

1. **Immediate Actions:**
   ```r
   # Increase difficulty globally
   captcha_configure(default_difficulty = "extreme")

   # Reduce rate limits
   # Update rate_limit_max_attempts to 5

   # Enable strict mode everywhere
   # Set strict_mode = TRUE in all verify calls
   ```

2. **Investigation:**
   ```r
   # Get detailed statistics
   stats <- captcha_get_stats(time_window_seconds = 86400)

   # Identify suspicious sessions
   suspicious <- stats$attempts[stats$attempts$success_rate > 0.95, ]

   # Review high-risk scores
   high_risk <- stats$attempts[stats$attempts$risk_score > 70, ]
   ```

3. **Mitigation:**
   - Block identified session IDs
   - Implement additional verification
   - Update distortion parameters
   - Consider alternative captcha types

## Reporting Security Issues

If you discover a security vulnerability, please email:

📧 **julio.trecenti@gmail.com**

**Do NOT** open public GitHub issues for security vulnerabilities.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested mitigation (if any)

## Version Support

| Version | Supported |
|---------|-----------|
| 0.3.x   | ✅ Yes    |
| 0.2.x   | ⚠️ Limited (original features only) |
| < 0.2   | ❌ No     |

## Compliance

This package is designed to help implement security controls but:
- ⚠️ Compliance is the responsibility of the implementing organization
- ⚠️ Regular security audits recommended
- ⚠️ Must be part of defense-in-depth strategy
- ⚠️ Not a replacement for proper authentication

## Additional Resources

- [OWASP CAPTCHA Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Captcha_Cheat_Sheet.html)
- [NIST Authentication Guidelines](https://pages.nist.gov/800-63-3/)
- Package examples: `inst/examples/anti_ai_example.R`

---

**Last Updated**: 2025-11-04
**Version**: 0.3.0.9000
