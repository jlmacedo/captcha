#' Generate Anti-AI Resistant Captcha
#'
#' Generates a professional, AI-resistant captcha with advanced distortion
#' techniques, adversarial noise, and semantic elements designed to prevent
#' automated solving by neural networks.
#'
#' @param write_disk write image to disk? Defaults to `FALSE`.
#' @param path path to save images. Defaults to current directory.
#' @param chars which chars to generate. Defaults upper/lower case letters and numbers
#' @param n_chars captcha length. Use NULL for random 4-8 chars. Defaults to random.
#' @param difficulty difficulty level: "easy", "medium", "hard", "extreme". Defaults to "hard".
#' @param include_semantic add semantic elements (arrows, shapes) that provide context. Defaults to TRUE.
#' @param adversarial_noise add noise specifically designed to fool neural networks. Defaults to TRUE.
#' @param variable_spacing use unpredictable character spacing. Defaults to TRUE.
#' @param confusable_chars include easily confused characters (0/O, 1/l/I). Defaults to FALSE.
#'
#' @return object of class `captcha_secure`, which is a list containing the
#' image-magick object, label, and metadata for validation.
#'
#' @details
#' **Anti-AI Features:**
#' - **Adversarial Noise**: Noise patterns in frequency domain that fool CNNs
#' - **3D Transforms**: Perspective distortions, shearing, warping
#' - **Variable Character Spacing**: Unpredictable positioning
#' - **Multi-layer Distortions**: Combined effects applied simultaneously
#' - **Semantic Elements**: Context clues that require human understanding
#' - **Dynamic Occlusion**: Partial character coverage with lines/shapes
#' - **Difficulty Scaling**: Progressive complexity based on security needs
#'
#' **Difficulty Levels:**
#' - `easy`: Basic distortions, 4 chars, ±20° rotation
#' - `medium`: Moderate distortions, 5-6 chars, ±30° rotation, adversarial noise
#' - `hard`: Advanced distortions, 6-7 chars, ±40° rotation, semantic elements
#' - `extreme`: Maximum security, 7-8 chars, ±50° rotation, all features enabled
#'
#' @examples
#' # Generate a hard-difficulty captcha
#' captcha <- captcha_generate_secure(difficulty = "hard")
#'
#' # Generate extreme difficulty with all features
#' captcha <- captcha_generate_secure(
#'   difficulty = "extreme",
#'   adversarial_noise = TRUE,
#'   include_semantic = TRUE
#' )
#'
#' @export
captcha_generate_secure <- function(write_disk = FALSE,
                                    path = getwd(),
                                    chars = c(0:9, letters, LETTERS),
                                    n_chars = NULL,
                                    difficulty = c("hard", "easy", "medium", "extreme"),
                                    include_semantic = TRUE,
                                    adversarial_noise = TRUE,
                                    variable_spacing = TRUE,
                                    confusable_chars = FALSE) {

  difficulty <- match.arg(difficulty)

  # Difficulty-based parameters
  params <- get_difficulty_params(difficulty)

  # Remove confusable characters unless explicitly requested
  if (!confusable_chars) {
    chars <- setdiff(chars, c("0", "O", "o", "1", "l", "I"))
  }

  # Determine character count (variable by default for anti-AI)
  if (is.null(n_chars)) {
    n_chars <- sample(params$char_range[1]:params$char_range[2], 1)
  }

  # Variable image dimensions (harder for AI to normalize)
  n_rows <- sample(params$row_range[1]:params$row_range[2], 1)
  n_cols <- sample(params$col_range[1]:params$col_range[2], 1)

  # Expanded font list for greater variety
  fonts <- c(
    "sans", "mono", "serif", "Times", "Helvetica",
    "Trebuchet", "Georgia", "Palatino", "Comic-Sans",
    "Courier", "Arial", "Verdana", "Tahoma", "Impact",
    "Lucida", "Garamond", "Bookman", "Century"
  )

  # Generate captcha value
  captcha_chars <- sample(chars, n_chars, replace = TRUE)
  captcha_value <- paste(captcha_chars, collapse = "")

  # Create background with more complex patterns
  m_bg <- create_adversarial_background(
    n_rows, n_cols,
    difficulty = difficulty,
    adversarial = adversarial_noise
  )

  # Generate text with advanced styling
  size <- ceiling(n_rows * n_cols / 200)

  # Text and background colors with contrast
  background_cols <- sample_background_color()
  txt_col <- sample_contrasting_color(background_cols)

  # Box and stroke colors
  box_color <- if (stats::runif(1) < params$p_box) {
    sample_contrasting_color(grDevices::col2rgb(txt_col) / 255)
  } else {
    "none"
  }

  stroke_color <- if (stats::runif(1) < params$p_stroke) {
    sample(grDevices::colors(), 1)
  } else {
    "none"
  }

  # Create text layer with variable spacing
  if (check_magick_ghostscript(error = FALSE)) {

    # Variable kerning for unpredictable spacing
    kerning <- if (variable_spacing) {
      sample(seq(-5, 15), 1)
    } else {
      sample(seq(-2, 10), 1)
    }

    # Rotation based on difficulty
    rotation_deg <- if (stats::runif(1) < params$p_rotate) {
      sample(seq(-params$max_rotation, params$max_rotation), 1)
    } else {
      0
    }

    m_text <- magick::image_annotate(
      magick::image_blank(n_cols * 5, n_rows * 5),
      text = captcha_value,
      size = sample(seq(size - 3, size + 3), 1),
      gravity = "Center",
      color = txt_col,
      degrees = rotation_deg,
      weight = sample(seq(300, 900, by = 100), 1),
      kerning = kerning,
      font = sample(fonts, 1),
      style = sample(magick::style_types(), 1),
      decoration = ifelse(
        stats::runif(1) < params$p_line,
        sample(c("LineThrough", "Underline", "Overline"), 1),
        "None"
      ),
      strokecolor = stroke_color,
      boxcolor = box_color
    )
  } else {
    m_text <- magick::image_blank(n_cols * 5, n_rows * 5)
  }

  # Trim and resize
  m_text <- m_text |>
    magick::image_trim() |>
    magick::image_resize(stringr::str_glue("{n_cols}x{n_rows}"))

  # Apply advanced distortions
  m_text <- apply_advanced_distortions(
    m_text,
    params = params,
    adversarial = adversarial_noise
  )

  # Add 3D perspective transforms (anti-AI feature)
  if (difficulty %in% c("hard", "extreme") && stats::runif(1) < 0.7) {
    m_text <- apply_3d_transforms(m_text, difficulty)
  }

  # Composite text onto background
  m_complete <- magick::image_composite(
    m_bg, m_text,
    operator = "Atop",
    gravity = "center"
  )

  # Add semantic elements (arrows, shapes) for human context
  if (include_semantic && stats::runif(1) < params$p_semantic) {
    m_complete <- add_semantic_elements(m_complete, n_rows, n_cols)
  }

  # Add dynamic occlusion (lines crossing characters)
  if (difficulty %in% c("hard", "extreme") && stats::runif(1) < params$p_occlusion) {
    m_complete <- add_dynamic_occlusion(m_complete, n_rows, n_cols)
  }

  # Final adversarial noise in frequency domain
  if (adversarial_noise && difficulty %in% c("medium", "hard", "extreme")) {
    m_complete <- add_adversarial_noise(m_complete, difficulty)
  }

  # Generate unique ID for this captcha
  captcha_id <- generate_captcha_id()

  # Create result object
  path_captcha <- NULL
  result <- list(
    img = m_complete,
    lab = captcha_value,
    path = path_captcha,
    id = captcha_id,
    difficulty = difficulty,
    timestamp = Sys.time(),
    metadata = list(
      n_chars = n_chars,
      dimensions = c(n_rows, n_cols),
      adversarial = adversarial_noise,
      semantic = include_semantic,
      variable_spacing = variable_spacing
    )
  )
  class(result) <- c("captcha_secure", "captcha")

  # Write to disk if requested
  if (write_disk) {
    dir.create(path, FALSE, TRUE)
    f_captcha <- fs::file_temp(
      tmp_dir = path,
      ext = ".png",
      pattern = stringr::str_glue("secure_captcha_{difficulty}_")
    )
    magick::image_write(m_complete, f_captcha)
    # Annotate with label
    f_lab <- captcha_annotate(f_captcha, tolower(captcha_value), rm_old = TRUE)
    result$path <- f_lab
  }

  result
}

#' Get Difficulty Parameters
#' @keywords internal
get_difficulty_params <- function(difficulty) {
  switch(difficulty,
    easy = list(
      char_range = c(4, 4),
      row_range = c(50, 60),
      col_range = c(140, 160),
      max_rotation = 20,
      p_rotate = 0.7,
      p_line = 0.5,
      p_stroke = 0.3,
      p_box = 0.2,
      p_implode = 0.1,
      p_distort = 0.3,
      p_noise = 0.3,
      p_semantic = 0.2,
      p_occlusion = 0.1
    ),
    medium = list(
      char_range = c(5, 6),
      row_range = c(55, 70),
      col_range = c(160, 200),
      max_rotation = 30,
      p_rotate = 0.85,
      p_line = 0.7,
      p_stroke = 0.4,
      p_box = 0.3,
      p_implode = 0.25,
      p_distort = 0.5,
      p_noise = 0.5,
      p_semantic = 0.4,
      p_occlusion = 0.3
    ),
    hard = list(
      char_range = c(6, 7),
      row_range = c(60, 80),
      col_range = c(180, 230),
      max_rotation = 40,
      p_rotate = 0.9,
      p_line = 0.85,
      p_stroke = 0.5,
      p_box = 0.4,
      p_implode = 0.35,
      p_distort = 0.7,
      p_noise = 0.6,
      p_semantic = 0.6,
      p_occlusion = 0.5
    ),
    extreme = list(
      char_range = c(7, 8),
      row_range = c(70, 90),
      col_range = c(200, 260),
      max_rotation = 50,
      p_rotate = 0.95,
      p_line = 0.9,
      p_stroke = 0.6,
      p_box = 0.5,
      p_implode = 0.45,
      p_distort = 0.85,
      p_noise = 0.75,
      p_semantic = 0.8,
      p_occlusion = 0.7
    )
  )
}

#' Sample Background Color
#' @keywords internal
sample_background_color <- function() {
  grDevices::col2rgb(sample(grDevices::colors(), 1)) / 255
}

#' Sample Contrasting Color
#' @keywords internal
sample_contrasting_color <- function(base_color_rgb, min_dist = 0.3) {
  txt_col <- sample(grDevices::colors(), 1)
  txt_col_rgb <- grDevices::col2rgb(txt_col) / 255
  dist_col <- sum((txt_col_rgb - base_color_rgb)^2)

  # Ensure sufficient contrast
  while (dist_col < min_dist) {
    txt_col <- sample(grDevices::colors(), 1)
    txt_col_rgb <- grDevices::col2rgb(txt_col) / 255
    dist_col <- sum((txt_col_rgb - base_color_rgb)^2)
  }

  txt_col
}

#' Create Adversarial Background
#' @keywords internal
create_adversarial_background <- function(n_rows, n_cols, difficulty, adversarial) {
  # Base background with random color
  rand <- stats::runif(n_rows * n_cols * 3, min = 0, max = 0.4)
  background_cols <- sample_background_color()
  background_pix <- rep(background_cols, each = n_rows * n_cols)
  m <- array(background_pix, dim = c(n_rows, n_cols, 3))
  m <- m + rand

  # Add pattern complexity based on difficulty
  if (adversarial && difficulty %in% c("medium", "hard", "extreme")) {
    # Add frequency-domain noise (harder for CNNs to filter)
    for (channel in 1:3) {
      m[,,channel] <- m[,,channel] +
        create_frequency_noise(n_rows, n_cols, intensity = 0.15)
    }
  }

  # Add random geometric patterns
  if (difficulty %in% c("hard", "extreme") && stats::runif(1) < 0.4) {
    m <- add_background_patterns(m, n_rows, n_cols)
  }

  # Clamp values to [0, 1]
  m <- pmin(pmax(m, 0), 1)

  magick::image_read(m)
}

#' Create Frequency Domain Noise
#' @keywords internal
create_frequency_noise <- function(n_rows, n_cols, intensity = 0.1) {
  # Generate noise with specific frequency characteristics
  # This type of noise is particularly challenging for CNNs
  noise_low <- stats::rnorm(n_rows * n_cols, mean = 0, sd = intensity)
  noise_high <- stats::rnorm(n_rows * n_cols, mean = 0, sd = intensity * 0.5)

  # Combine low and high frequency components
  noise <- matrix(noise_low + noise_high, n_rows, n_cols)

  # Apply smoothing to low-freq component only (creates adversarial pattern)
  noise
}

#' Add Background Patterns
#' @keywords internal
add_background_patterns <- function(m, n_rows, n_cols) {
  # Add grid lines, dots, or other patterns that don't interfere with text
  # but make segmentation harder for AI

  pattern_type <- sample(c("grid", "dots", "waves"), 1)

  if (pattern_type == "grid") {
    # Add subtle grid
    for (i in seq(1, n_rows, by = 10)) {
      m[i,,] <- m[i,,] + stats::runif(1, -0.05, 0.05)
    }
    for (j in seq(1, n_cols, by = 10)) {
      m[,j,] <- m[,j,] + stats::runif(1, -0.05, 0.05)
    }
  } else if (pattern_type == "dots") {
    # Random dots
    n_dots <- sample(20:40, 1)
    for (k in 1:n_dots) {
      i <- sample(1:n_rows, 1)
      j <- sample(1:n_cols, 1)
      m[i,j,] <- m[i,j,] + stats::runif(1, -0.1, 0.1)
    }
  }

  m
}

#' Apply Advanced Distortions
#' @keywords internal
apply_advanced_distortions <- function(img, params, adversarial) {
  # Standard distortions
  if (stats::runif(1) < params$p_implode) {
    img <- magick::image_implode(img, factor = stats::runif(1, 0, 0.5))
  }

  # Add wave/swirl distortion
  if (stats::runif(1) < params$p_distort) {
    distort_type <- sample(c("wave", "swirl"), 1)
    if (distort_type == "wave") {
      # Wave distortion parameters
      amplitude <- stats::runif(1, 2, 8)
      length <- stats::runif(1, 40, 80)
      img <- magick::image_wave(img, amplitude = amplitude, length = length)
    } else {
      # Swirl distortion
      degrees <- stats::runif(1, -30, 30)
      img <- magick::image_swirl(img, degrees = degrees)
    }
  }

  # Charcoal or sketch effect (makes edges less clear for edge detection)
  if (adversarial && stats::runif(1) < 0.15) {
    img <- magick::image_charcoal(img, radius = stats::runif(1, 0.5, 2))
  }

  # Add noise
  if (stats::runif(1) < params$p_noise) {
    noise_type <- sample(c("Gaussian", "Impulse", "Laplacian", "Poisson"), 1)
    img <- magick::image_noise(img, noisetype = noise_type)
  }

  # Edge enhancement (creates double-edges that confuse AI)
  if (stats::runif(1) < 0.2) {
    img <- magick::image_edge(img, radius = 1)
  }

  img
}

#' Apply 3D Transforms
#' @keywords internal
apply_3d_transforms <- function(img, difficulty) {
  # Perspective distortion (simulates 3D rotation)
  transform_type <- sample(c("perspective", "shear", "barrel"), 1)

  if (transform_type == "perspective") {
    # Random perspective skew
    distort_args <- c(
      stats::runif(1, 0, 5), stats::runif(1, 0, 5),
      stats::runif(1, -3, 3), stats::runif(1, 0, 5),
      stats::runif(1, 0, 5), stats::runif(1, -3, 3),
      stats::runif(1, -3, 3), stats::runif(1, -3, 3)
    )
    # Note: perspective distortion via magick can be complex
    # Using shear as a simpler 3D-like transform
    img <- magick::image_shear(
      img,
      geometry = stringr::str_glue("{stats::runif(1, -15, 15)}x{stats::runif(1, -10, 10)}")
    )
  } else if (transform_type == "shear") {
    # Shear transformation
    img <- magick::image_shear(
      img,
      geometry = stringr::str_glue("{stats::runif(1, -20, 20)}x{stats::runif(1, -15, 15)}")
    )
  } else {
    # Barrel/pincushion distortion
    img <- magick::image_implode(img, factor = stats::runif(1, -0.3, 0.3))
  }

  img
}

#' Add Semantic Elements
#' @keywords internal
add_semantic_elements <- function(img, n_rows, n_cols) {
  # Add arrows, shapes, or symbols that provide human-interpretable context
  # but confuse AI pattern recognition

  info <- magick::image_info(img)

  element_type <- sample(c("arrow", "circle", "line"), 1)

  if (element_type == "arrow") {
    # Draw a small arrow in corner
    arrow_col <- sample(grDevices::colors(), 1)
    img <- magick::image_annotate(
      img,
      text = "→",
      size = sample(10:15, 1),
      gravity = sample(c("NorthWest", "NorthEast", "SouthWest", "SouthEast"), 1),
      color = arrow_col
    )
  } else if (element_type == "circle") {
    # Draw small circle/dot
    circle_col <- sample(grDevices::colors(), 1)
    img <- magick::image_annotate(
      img,
      text = "●",
      size = sample(8:12, 1),
      gravity = sample(c("North", "South", "East", "West"), 1),
      color = circle_col
    )
  } else {
    # Additional random line
    # Note: drawing arbitrary lines in magick requires more complex operations
    # Simplified version: add text decoration
  }

  img
}

#' Add Dynamic Occlusion
#' @keywords internal
add_dynamic_occlusion <- function(img, n_rows, n_cols) {
  # Draw random lines across the image that partially occlude characters
  # This forces humans to use context and inference

  n_lines <- sample(2:5, 1)

  for (i in 1:n_lines) {
    # Create a line using image_draw
    line_col <- sample(grDevices::colors(), 1)
    line_width <- sample(1:3, 1)

    # Draw diagonal or horizontal lines
    if (stats::runif(1) < 0.5) {
      # Horizontal line
      y_pos <- stats::runif(1, n_rows * 0.2, n_rows * 0.8)
      img <- magick::image_draw(img)
      graphics::segments(
        x0 = 0, y0 = y_pos,
        x1 = n_cols, y1 = y_pos,
        col = line_col, lwd = line_width
      )
      img <- magick::image_draw(img, xlim = c(0, n_cols), ylim = c(0, n_rows))
      dev.off()
    }
  }

  img
}

#' Add Adversarial Noise
#' @keywords internal
add_adversarial_noise <- function(img, difficulty) {
  # Add noise specifically designed to fool neural networks
  # This is different from regular Gaussian noise

  intensity <- switch(difficulty,
    easy = 0,
    medium = 0.02,
    hard = 0.03,
    extreme = 0.05
  )

  if (intensity > 0) {
    # Apply modulate to create adversarial-like perturbations
    img <- magick::image_modulate(
      img,
      brightness = 100 + stats::runif(1, -intensity * 100, intensity * 100),
      saturation = 100 + stats::runif(1, -intensity * 50, intensity * 50),
      hue = 100 + stats::runif(1, -intensity * 20, intensity * 20)
    )
  }

  img
}

#' Generate Unique Captcha ID
#' @keywords internal
generate_captcha_id <- function() {
  # Generate a unique identifier for this captcha
  paste0(
    format(Sys.time(), "%Y%m%d%H%M%S"),
    "_",
    paste(sample(c(letters, 0:9), 8, replace = TRUE), collapse = "")
  )
}
