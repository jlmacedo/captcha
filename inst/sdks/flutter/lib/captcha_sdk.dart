/// Anti-AI Captcha Flutter SDK
///
/// Official Flutter SDK for integrating Anti-AI Captcha into Flutter applications
/// Supports iOS and Android platforms
library captcha_sdk;

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Captcha SDK Configuration
class CaptchaConfig {
  final String apiKey;
  final String apiUrl;
  final CaptchaDifficulty difficulty;
  final CaptchaTheme theme;

  const CaptchaConfig({
    required this.apiKey,
    this.apiUrl = 'https://captcha-api.example.com',
    this.difficulty = CaptchaDifficulty.medium,
    this.theme = CaptchaTheme.light,
  });
}

/// Captcha Difficulty Levels
enum CaptchaDifficulty {
  easy,
  medium,
  hard,
  extreme;

  String get value => name;
}

/// Captcha Theme
enum CaptchaTheme {
  light,
  dark;

  String get value => name;
}

/// Captcha Challenge Data
class CaptchaChallenge {
  final String captchaId;
  final String token;
  final String imageBase64;
  final DateTime expiresAt;
  final int expiresInSeconds;
  final String difficulty;

  CaptchaChallenge({
    required this.captchaId,
    required this.token,
    required this.imageBase64,
    required this.expiresAt,
    required this.expiresInSeconds,
    required this.difficulty,
  });

  factory CaptchaChallenge.fromJson(Map<String, dynamic> json) {
    return CaptchaChallenge(
      captchaId: json['captcha_id'],
      token: json['token'],
      imageBase64: json['image']['base64'],
      expiresAt: DateTime.parse(json['expires_at']),
      expiresInSeconds: json['expires_in_seconds'],
      difficulty: json['difficulty'],
    );
  }
}

/// Captcha Verification Result
class CaptchaVerificationResult {
  final bool valid;
  final String message;
  final int riskScore;
  final String riskLevel;
  final List<String> warnings;

  CaptchaVerificationResult({
    required this.valid,
    required this.message,
    required this.riskScore,
    required this.riskLevel,
    required this.warnings,
  });

  factory CaptchaVerificationResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final riskAssessment = data['risk_assessment'];

    return CaptchaVerificationResult(
      valid: data['valid'],
      message: data['message'],
      riskScore: riskAssessment['risk_score'],
      riskLevel: riskAssessment['risk_level'],
      warnings: List<String>.from(riskAssessment['warnings'] ?? []),
    );
  }
}

/// Captcha API Client
class CaptchaClient {
  final CaptchaConfig config;
  late final String _sessionId;

  CaptchaClient(this.config) {
    _sessionId = _generateSessionId();
  }

  String _generateSessionId() {
    return 'flutter_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }

  /// Create a new captcha challenge
  Future<CaptchaChallenge> createChallenge({
    CaptchaDifficulty? difficulty,
    bool useProgressive = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${config.apiUrl}/api/v1/captcha/create'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': config.apiKey,
        },
        body: json.encode({
          'difficulty': (difficulty ?? config.difficulty).value,
          'session_id': _sessionId,
          'use_progressive': useProgressive,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return CaptchaChallenge.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw CaptchaException(error['error'] ?? 'Failed to create captcha');
      }
    } catch (e) {
      throw CaptchaException('Network error: $e');
    }
  }

  /// Verify captcha solution
  Future<CaptchaVerificationResult> verify({
    required String captchaId,
    required String token,
    required String answer,
    required Duration solveTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${config.apiUrl}/api/v1/captcha/verify'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': config.apiKey,
        },
        body: json.encode({
          'captcha_id': captchaId,
          'token': token,
          'answer': answer,
          'solve_time': solveTime.inMilliseconds,
          'session_id': _sessionId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return CaptchaVerificationResult.fromJson(data);
      } else {
        return CaptchaVerificationResult.fromJson(data);
      }
    } catch (e) {
      throw CaptchaException('Network error: $e');
    }
  }
}

/// Captcha Exception
class CaptchaException implements Exception {
  final String message;

  CaptchaException(this.message);

  @override
  String toString() => 'CaptchaException: $message';
}

/// Captcha Widget
class CaptchaWidget extends StatefulWidget {
  final CaptchaConfig config;
  final void Function(String captchaId, String token) onSuccess;
  final void Function(String error)? onError;
  final void Function()? onExpire;
  final CaptchaDifficulty? difficulty;
  final bool useProgressive;

  const CaptchaWidget({
    Key? key,
    required this.config,
    required this.onSuccess,
    this.onError,
    this.onExpire,
    this.difficulty,
    this.useProgressive = false,
  }) : super(key: key);

  @override
  State<CaptchaWidget> createState() => _CaptchaWidgetState();
}

class _CaptchaWidgetState extends State<CaptchaWidget> {
  late CaptchaClient _client;
  CaptchaChallenge? _challenge;
  bool _loading = false;
  String? _error;
  bool _verifying = false;
  bool _verified = false;
  final _controller = TextEditingController();
  DateTime? _startTime;
  Timer? _expiryTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _client = CaptchaClient(widget.config);
    _loadChallenge();
  }

  @override
  void dispose() {
    _controller.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    setState(() {
      _loading = true;
      _error = null;
      _verified = false;
    });

    try {
      final challenge = await _client.createChallenge(
        difficulty: widget.difficulty,
        useProgressive: widget.useProgressive,
      );

      setState(() {
        _challenge = challenge;
        _loading = false;
        _startTime = DateTime.now();
        _controller.clear();
      });

      _startExpiryTimer();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      widget.onError?.call(e.toString());
    }
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_challenge == null) return;

      final remaining = _challenge!.expiresAt.difference(DateTime.now());
      if (remaining.isNegative) {
        timer.cancel();
        widget.onExpire?.call();
        _loadChallenge();
      } else {
        setState(() {
          _remainingSeconds = remaining.inSeconds;
        });
      }
    });
  }

  Future<void> _verify() async {
    if (_challenge == null || _controller.text.isEmpty) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    final solveTime = DateTime.now().difference(_startTime!);

    try {
      final result = await _client.verify(
        captchaId: _challenge!.captchaId,
        token: _challenge!.token,
        answer: _controller.text.trim(),
        solveTime: solveTime,
      );

      if (result.valid) {
        setState(() {
          _verified = true;
          _verifying = false;
        });
        widget.onSuccess(_challenge!.captchaId, _challenge!.token);
      } else {
        setState(() {
          _error = result.message;
          _verifying = false;
        });
        widget.onError?.call(result.message);

        // Auto-reload after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        _loadChallenge();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _verifying = false;
      });
      widget.onError?.call(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.config.theme == CaptchaTheme.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildContent(isDark),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_loading) {
      return _buildLoading(isDark);
    }

    if (_error != null && _challenge == null) {
      return _buildError(isDark);
    }

    if (_verified) {
      return _buildSuccess(isDark);
    }

    return _buildCaptcha(isDark);
  }

  Widget _buildLoading(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Loading captcha...',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildError(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(
          _error ?? 'An error occurred',
          style: TextStyle(color: Colors.red, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadChallenge,
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _buildSuccess(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'Verification successful!',
          style: TextStyle(
            color: Colors.green,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptcha(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Captcha Image
        if (_challenge != null)
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Image.memory(
                  base64Decode(_challenge!.imageBase64),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadChallenge,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Input field
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Enter the text above',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
          ),
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 2,
            fontSize: 16,
          ),
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          onSubmitted: (_) => _verify(),
        ),

        const SizedBox(height: 12),

        // Verify button
        ElevatedButton(
          onPressed: _verifying ? null : _verify,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _verifying
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify', style: TextStyle(fontSize: 15)),
        ),

        // Error message
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[200]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Expiry timer
        if (_challenge != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Expires in ${_remainingSeconds}s',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
