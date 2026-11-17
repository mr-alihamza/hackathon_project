import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Client for the server-side AI project generation endpoint.
///
/// The Gemini API key lives only in the Cloud Function secret store; this
/// service authenticates with the signed-in user's Firebase ID token and
/// sends a stable [requestId] so retries never create duplicate generations.
class GeminiService {
  static const _endpoint = String.fromEnvironment(
    'AI_ENDPOINT',
    defaultValue:
        'https://us-central1-test-project-f69c6.cloudfunctions.net/generateProjects',
  );

  static const _maxAttempts = 3;
  static const _requestTimeout = Duration(seconds: 300);

  final http.Client _client = http.Client();

  String newRequestId() {
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  Future<Map<String, dynamic>> generateProjects({
    required String transcript,
    required String requestId,
  }) async {
    if (transcript.trim().isEmpty) {
      throw Exception('Please enter the meeting transcript.');
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('You must be signed in to generate projects.');
    }

    final idToken = await user.getIdToken();

    if (idToken == null) {
      throw Exception('Could not authenticate the request.');
    }

    Object? lastError;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        return await _post(idToken, transcript, requestId);
      } on _RetryableException catch (e) {
        lastError = e;

        if (attempt == _maxAttempts - 1) break;

        await Future<void>.delayed(_backoff(attempt));
      }
    }

    throw lastError ?? Exception('AI generation failed. Please try again.');
  }

  Duration _backoff(int attempt) {
    // Exponential backoff: ~2s, ~6s plus jitter.
    final base = 2000 * pow(3, attempt).round();
    final jitter = Random().nextInt(500);

    return Duration(milliseconds: base + jitter);
  }

  Future<Map<String, dynamic>> _post(
    String idToken,
    String transcript,
    String requestId,
  ) async {
    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'transcript': transcript,
            'requestId': requestId,
          }),
        )
        .timeout(_requestTimeout);

    Map<String, dynamic> body = {};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {
      // Non-JSON error body; fall back to the HTTP status message below.
    }

    if (response.statusCode == 200) {
      final result = body['projects'];

      if (result is! List) {
        throw Exception('AI returned an invalid project structure.');
      }

      return body;
    }

    final message = body['error'] is String
        ? body['error'] as String
        : 'AI generation failed (HTTP ${response.statusCode}).';

    if (_isRetryableStatus(response.statusCode)) {
      throw _RetryableException(message);
    }

    throw Exception(message);
  }

  bool _isRetryableStatus(int status) {
    // 409 means a previous attempt is still running; surface it as a normal
    // error because retrying immediately would not help.
    return status == 408 || status == 429 || status >= 500;
  }

  void dispose() {
    _client.close();
  }
}

class _RetryableException implements Exception {
  _RetryableException(this.message);

  final String message;

  @override
  String toString() => message;
}
