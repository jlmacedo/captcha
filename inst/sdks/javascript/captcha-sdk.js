/**
 * Anti-AI Captcha JavaScript SDK
 *
 * Official JavaScript SDK for integrating Anti-AI Captcha into web applications
 * Supports login, register, password recovery, and email validation forms
 *
 * @version 1.0.0
 * @license MIT
 */

(function(global) {
  'use strict';

  /**
   * Captcha SDK Configuration
   */
  class CaptchaSDK {
    constructor(config) {
      this.apiKey = config.apiKey;
      this.apiUrl = config.apiUrl || 'https://captcha-api.example.com';
      this.difficulty = config.difficulty || 'medium';
      this.theme = config.theme || 'light';
      this.language = config.language || 'en';
      this.onSuccess = config.onSuccess || function() {};
      this.onError = config.onError || function() {};
      this.onExpire = config.onExpire || function() {};

      this.currentChallenge = null;
      this.startTime = null;
      this.mouseMovements = [];
      this.keypressIntervals = [];
      this.lastKeypress = null;
    }

    /**
     * Render captcha widget in container
     * @param {string|HTMLElement} container - Container element or selector
     * @param {object} options - Rendering options
     */
    render(container, options = {}) {
      const element = typeof container === 'string'
        ? document.querySelector(container)
        : container;

      if (!element) {
        console.error('Captcha container not found');
        return;
      }

      // Merge options
      const renderOptions = {
        difficulty: options.difficulty || this.difficulty,
        useProgressive: options.useProgressive || false,
        collectBehavior: options.collectBehavior !== false,
        ...options
      };

      // Create widget HTML
      element.innerHTML = this._createWidgetHTML();
      element.classList.add('captcha-container');

      // Apply theme
      element.classList.add(`captcha-theme-${this.theme}`);

      // Store reference
      this.container = element;
      this.options = renderOptions;

      // Add event listeners
      this._attachEventListeners();

      // Load captcha challenge
      this.reset();
    }

    /**
     * Create widget HTML structure
     * @private
     */
    _createWidgetHTML() {
      return `
        <div class="captcha-widget">
          <div class="captcha-loading" style="display: none;">
            <div class="captcha-spinner"></div>
            <p>Loading captcha...</p>
          </div>

          <div class="captcha-content" style="display: none;">
            <div class="captcha-image-container">
              <img class="captcha-image" alt="Captcha challenge" />
              <button class="captcha-refresh" title="Get new captcha" type="button">
                <svg width="20" height="20" viewBox="0 0 20 20">
                  <path d="M14.66 15.66A8 8 0 1 1 17 10h-2a6 6 0 1 0-1.76 4.24l1.42 1.42zM12 10h8l-4 4-4-4z"/>
                </svg>
              </button>
            </div>

            <div class="captcha-input-container">
              <input
                type="text"
                class="captcha-input"
                placeholder="Enter the text above"
                autocomplete="off"
                spellcheck="false"
                maxlength="10"
              />
              <button class="captcha-submit" type="button">Verify</button>
            </div>

            <div class="captcha-status"></div>
            <div class="captcha-expiry"></div>
          </div>

          <div class="captcha-error" style="display: none;">
            <p class="captcha-error-message"></p>
            <button class="captcha-retry" type="button">Try Again</button>
          </div>
        </div>
      `;
    }

    /**
     * Attach event listeners
     * @private
     */
    _attachEventListeners() {
      const input = this.container.querySelector('.captcha-input');
      const submitBtn = this.container.querySelector('.captcha-submit');
      const refreshBtn = this.container.querySelector('.captcha-refresh');
      const retryBtn = this.container.querySelector('.captcha-retry');

      // Submit on enter key
      input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          this.verify();
        }

        // Track keypress timing
        if (this.options.collectBehavior) {
          this._trackKeypress();
        }
      });

      // Submit button
      submitBtn.addEventListener('click', () => this.verify());

      // Refresh button
      refreshBtn.addEventListener('click', () => this.reset());

      // Retry button
      retryBtn.addEventListener('click', () => this.reset());

      // Track mouse movements
      if (this.options.collectBehavior) {
        this.container.addEventListener('mousemove', (e) => {
          this._trackMouseMovement(e);
        });
      }

      // Focus input when clicking on image
      const imageContainer = this.container.querySelector('.captcha-image-container');
      imageContainer.addEventListener('click', () => {
        input.focus();
      });
    }

    /**
     * Load new captcha challenge
     */
    async reset() {
      this._showLoading();
      this._clearBehaviorData();

      try {
        const response = await fetch(`${this.apiUrl}/api/v1/captcha/create`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': this.apiKey
          },
          body: JSON.stringify({
            difficulty: this.options.difficulty,
            session_id: this._getSessionId(),
            use_progressive: this.options.useProgressive
          })
        });

        if (!response.ok) {
          const error = await response.json();
          throw new Error(error.message || 'Failed to load captcha');
        }

        const result = await response.json();
        this.currentChallenge = result.data;
        this.startTime = Date.now();

        // Display captcha
        this._displayCaptcha();

        // Set expiry timer
        this._startExpiryTimer();

      } catch (error) {
        this._showError(error.message);
        this.onError(error);
      }
    }

    /**
     * Verify captcha solution
     */
    async verify() {
      const input = this.container.querySelector('.captcha-input');
      const answer = input.value.trim();

      if (!answer) {
        this._showStatus('Please enter the captcha text', 'error');
        return;
      }

      if (!this.currentChallenge) {
        this._showError('No captcha challenge loaded');
        return;
      }

      this._showLoading('Verifying...');

      const solveTime = Date.now() - this.startTime;

      try {
        const response = await fetch(`${this.apiUrl}/api/v1/captcha/verify`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': this.apiKey
          },
          body: JSON.stringify({
            captcha_id: this.currentChallenge.captcha_id,
            token: this.currentChallenge.token,
            answer: answer,
            solve_time: solveTime,
            session_id: this._getSessionId(),
            behavior_data: this._getBehaviorData()
          })
        });

        const result = await response.json();

        if (result.success && result.data.valid) {
          this._showSuccess();
          this.onSuccess({
            captcha_id: this.currentChallenge.captcha_id,
            solve_time: solveTime,
            risk_score: result.data.risk_assessment.risk_score
          });
        } else {
          this._showStatus(result.data.message || 'Incorrect captcha', 'error');

          // Auto-reload after failure
          setTimeout(() => this.reset(), 2000);

          this.onError(new Error(result.data.message));
        }

      } catch (error) {
        this._showError(error.message);
        this.onError(error);
      }
    }

    /**
     * Get current captcha token (for server-side verification)
     */
    getToken() {
      return this.currentChallenge ? this.currentChallenge.token : null;
    }

    /**
     * Get current captcha ID
     */
    getCaptchaId() {
      return this.currentChallenge ? this.currentChallenge.captcha_id : null;
    }

    /**
     * Display captcha image
     * @private
     */
    _displayCaptcha() {
      const img = this.container.querySelector('.captcha-image');
      const input = this.container.querySelector('.captcha-input');
      const content = this.container.querySelector('.captcha-content');
      const loading = this.container.querySelector('.captcha-loading');

      // Set image
      img.src = `data:image/png;base64,${this.currentChallenge.image.base64}`;

      // Reset input
      input.value = '';

      // Show content, hide loading
      loading.style.display = 'none';
      content.style.display = 'block';

      // Focus input
      setTimeout(() => input.focus(), 100);
    }

    /**
     * Show loading state
     * @private
     */
    _showLoading(message = 'Loading...') {
      const loading = this.container.querySelector('.captcha-loading');
      const content = this.container.querySelector('.captcha-content');
      const error = this.container.querySelector('.captcha-error');

      loading.querySelector('p').textContent = message;
      loading.style.display = 'block';
      content.style.display = 'none';
      error.style.display = 'none';
    }

    /**
     * Show error state
     * @private
     */
    _showError(message) {
      const loading = this.container.querySelector('.captcha-loading');
      const content = this.container.querySelector('.captcha-content');
      const error = this.container.querySelector('.captcha-error');
      const errorMessage = this.container.querySelector('.captcha-error-message');

      errorMessage.textContent = message;
      error.style.display = 'block';
      loading.style.display = 'none';
      content.style.display = 'none';
    }

    /**
     * Show status message
     * @private
     */
    _showStatus(message, type = 'info') {
      const status = this.container.querySelector('.captcha-status');
      status.textContent = message;
      status.className = `captcha-status captcha-status-${type}`;

      // Clear after 3 seconds
      setTimeout(() => {
        status.textContent = '';
        status.className = 'captcha-status';
      }, 3000);
    }

    /**
     * Show success state
     * @private
     */
    _showSuccess() {
      const content = this.container.querySelector('.captcha-content');
      content.innerHTML = `
        <div class="captcha-success">
          <svg class="captcha-success-icon" width="60" height="60" viewBox="0 0 60 60">
            <circle cx="30" cy="30" r="28" fill="#4CAF50"/>
            <path d="M20 30 L27 37 L40 24" stroke="white" stroke-width="4" fill="none" stroke-linecap="round"/>
          </svg>
          <p>Verification successful!</p>
        </div>
      `;
    }

    /**
     * Start expiry countdown timer
     * @private
     */
    _startExpiryTimer() {
      if (this.expiryTimer) {
        clearInterval(this.expiryTimer);
      }

      const expiryEl = this.container.querySelector('.captcha-expiry');
      const expiresAt = new Date(this.currentChallenge.expires_at);

      this.expiryTimer = setInterval(() => {
        const now = new Date();
        const remaining = Math.max(0, expiresAt - now);
        const seconds = Math.floor(remaining / 1000);

        if (seconds > 0) {
          expiryEl.textContent = `Expires in ${seconds}s`;
        } else {
          clearInterval(this.expiryTimer);
          expiryEl.textContent = 'Expired';
          this.onExpire();
          setTimeout(() => this.reset(), 1000);
        }
      }, 1000);
    }

    /**
     * Track mouse movement
     * @private
     */
    _trackMouseMovement(event) {
      const rect = this.container.getBoundingClientRect();
      this.mouseMovements.push({
        x: event.clientX - rect.left,
        y: event.clientY - rect.top,
        timestamp: Date.now()
      });

      // Keep only last 50 movements
      if (this.mouseMovements.length > 50) {
        this.mouseMovements.shift();
      }
    }

    /**
     * Track keypress timing
     * @private
     */
    _trackKeypress() {
      const now = Date.now();
      if (this.lastKeypress) {
        this.keypressIntervals.push(now - this.lastKeypress);
      }
      this.lastKeypress = now;
    }

    /**
     * Get behavior data for verification
     * @private
     */
    _getBehaviorData() {
      if (!this.options.collectBehavior) {
        return null;
      }

      return {
        mouse_movements: this.mouseMovements,
        keypress_intervals: this.keypressIntervals.map(i => i / 1000), // Convert to seconds
        paste_detected: false // TODO: Implement paste detection
      };
    }

    /**
     * Clear behavior tracking data
     * @private
     */
    _clearBehaviorData() {
      this.mouseMovements = [];
      this.keypressIntervals = [];
      this.lastKeypress = null;
      this.startTime = null;
    }

    /**
     * Get or create session ID
     * @private
     */
    _getSessionId() {
      let sessionId = sessionStorage.getItem('captcha_session_id');
      if (!sessionId) {
        sessionId = 'web_' + Math.random().toString(36).substring(2) + Date.now();
        sessionStorage.setItem('captcha_session_id', sessionId);
      }
      return sessionId;
    }

    /**
     * Destroy the widget
     */
    destroy() {
      if (this.expiryTimer) {
        clearInterval(this.expiryTimer);
      }
      if (this.container) {
        this.container.innerHTML = '';
        this.container.classList.remove('captcha-container');
      }
      this.currentChallenge = null;
    }
  }

  // Export for different module systems
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = CaptchaSDK;
  } else if (typeof define === 'function' && define.amd) {
    define(function() { return CaptchaSDK; });
  } else {
    global.CaptchaSDK = CaptchaSDK;
  }

})(typeof window !== 'undefined' ? window : this);
