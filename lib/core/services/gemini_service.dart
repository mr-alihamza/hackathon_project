import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/models/user_model.dart';

/// Direct Gemini API client.
///
/// NOTE: the API key is bundled with the app via `.env`. It is visible to
/// anyone who inspects the build — restrict the key in Google AI Studio and
/// rotate it if the app is distributed.
class GeminiService {
  String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];

    if (key == null || key.trim().isEmpty) {
      throw Exception('Gemini API key is missing.');
    }

    return key.trim();
  }

  List<String> get _models {
    final configured = dotenv.env['GEMINI_MODEL'] ?? 'gemini-3.8-flash';
    final models = <String>[configured, 'gemini-flash-latest'];

    // De-duplicate while preserving order.
    return models.toSet().toList();
  }

  static const _maxAttemptsPerModel = 3;
  static const _requestTimeout = Duration(seconds: 180);
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> generateProjects({
    required String transcript,
    required List<UserModel> team,
  }) async {
    if (transcript.trim().isEmpty) {
      throw Exception('Please enter the meeting transcript.');
    }

    final directory = team.map((member) {
      return {
        'employeeCode': member.employeeCode,
        'name': member.name,
        'role': member.role,
        'specialization': member.specialization,
        'skills': member.skills,
      };
    }).toList();

    final prompt = _buildPrompt(directory, transcript);

    Object? lastError;

    for (final model in _models) {
      try {
        return await _generateWithModel(model, prompt);
      } on _ModelUnavailableException catch (e) {
        lastError = e;
        // Try the next model only when this one is gone or overloaded.
        continue;
      }
    }

    throw lastError ?? Exception('AI generation failed. Please try again.');
  }

  Future<Map<String, dynamic>> _generateWithModel(
    String model,
    String prompt,
  ) async {
    Object? lastError;

    for (var attempt = 0; attempt < _maxAttemptsPerModel; attempt++) {
      try {
        final responseData = await _callOnce(model, prompt);
        return _extractProjects(responseData);
      } on _ModelUnavailableException {
        rethrow; // no point retrying a missing model
      } on _RetryableException catch (e) {
        lastError = e;

        if (attempt == _maxAttemptsPerModel - 1) break;

        await Future<void>.delayed(_backoff(attempt));
      }
    }

    throw lastError ?? Exception('AI generation failed. Please try again.');
  }

  Duration _backoff(int attempt) {
    // Exponential backoff: ~2s, ~6s, ~18s plus jitter.
    final base = 2000 * pow(3, attempt).round();
    final jitter = Random().nextInt(500);

    return Duration(milliseconds: base + jitter);
  }

  Future<Map<String, dynamic>> _callOnce(
    String model,
    String prompt,
  ) async {
    final uri = Uri.parse('$_baseUrl/models/$model:generateContent');

    final http.Response response;

    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              // Header auth keeps the key out of URLs and proxy logs.
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.1,
                'responseMimeType': 'application/json',
                // Gemini 3.x is a thinking model; leave headroom for
                // reasoning tokens plus the JSON payload.
                'maxOutputTokens': 16384,
              },
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw _RetryableException('Gemini request timed out.');
    } on http.ClientException catch (e) {
      throw _RetryableException('Network error: ${e.message}');
    }

    if (response.statusCode == 200) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Gemini returned a malformed response.');
      }
    }

    final message = _extractError(response.body);

    if (response.statusCode == 404) {
      throw _ModelUnavailableException('Model "$model" is unavailable.');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Gemini rejected the API key (${response.statusCode}). '
        'Check GEMINI_API_KEY in .env.',
      );
    }

    if (response.statusCode == 400) {
      throw Exception('Gemini rejected the request: $message');
    }

    if (_isRetryableStatus(response.statusCode)) {
      throw _RetryableException('$message (HTTP ${response.statusCode})');
    }

    throw Exception(message);
  }

  bool _isRetryableStatus(int status) {
    return status == 408 || status == 429 || status >= 500;
  }

  Map<String, dynamic> _extractProjects(Map<String, dynamic> responseData) {
    final candidates = responseData['candidates'];

    if (candidates is! List || candidates.isEmpty) {
      final blockReason =
          responseData['promptFeedback']?['blockReason'] as String?;

      throw Exception(
        blockReason != null
            ? 'Gemini blocked the request ($blockReason).'
            : 'Gemini did not generate a response.',
      );
    }

    final candidate = candidates.first as Map<String, dynamic>;

    if (candidate['finishReason'] == 'MAX_TOKENS') {
      throw Exception(
        'Gemini response was truncated. Try a shorter transcript.',
      );
    }

    final content = candidate['content'];
    final parts = content is Map ? content['parts'] : null;

    if (parts is! List) {
      throw Exception('Gemini returned an invalid response structure.');
    }

    final generatedText = parts
        .where((part) => part is Map && part['text'] != null)
        .map((part) => part['text'].toString())
        .join();

    if (generatedText.trim().isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    final dynamic decoded;

    try {
      decoded = jsonDecode(generatedText);
    } catch (_) {
      throw Exception('Gemini returned malformed JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Gemini returned an invalid JSON structure.');
    }

    if (decoded['projects'] is! List) {
      throw Exception('Generated projects are missing.');
    }

    return decoded;
  }

  String _buildPrompt(List<Map<String, dynamic>> directory, String transcript) {
    return '''
You are an expert AI project manager for NovaWorks Technologies.

Convert the supplied meeting transcript into structured project and task data.

EXISTING TEAM DIRECTORY:
${jsonEncode(directory)}

IMPORTANT RULES:

1. Use only employees in the supplied directory.
2. Use employeeCode for managerCode and assigneeCode.
3. Never invent employees.
4. Never assign an ADMIN to a project or task.
5. Every project must have one existing MANAGER.
6. Every task must have one existing AGENT.
7. Preserve final decisions and corrections from the transcript.
8. Ignore rejected suggestions and future features.
9. Do not create additional projects that were not agreed.
10. Do not merge separate client projects.
11. Project dates must use YYYY-MM-DD.
12. Task dates must use YYYY-MM-DD.
13. Task deadlines cannot be after their project deadline.
14. Estimated hours must be positive numbers.
15. Estimate developer work only.
16. Do not create management-hour estimates.
17. Do not include costs, budgets, progress, or completion percentages.
18. Return every agreed task separately.
19. Descriptions must reflect the agreed scope.
20. Do not return markdown or explanatory text.

EXPECTED JSON:

{
  "projects": [
    {
      "name": "Project name",
      "clientName": "Client name",
      "description": "Project description",
      "managerCode": "PM01",
      "deadline": "2026-10-20",
      "tasks": [
        {
          "title": "Task title",
          "description": "Task description",
          "assigneeCode": "DEV01",
          "deadline": "2026-10-12",
          "estimatedHours": 12
        }
      ]
    }
  ]
}

MEETING TRANSCRIPT:

$transcript
''';
  }

  String _extractError(String body) {
    try {
      final data = jsonDecode(body);
      return data['error']?['message']?.toString() ??
          'Gemini request failed.';
    } catch (_) {
      return 'Gemini request failed. Please try again.';
    }
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

class _ModelUnavailableException implements Exception {
  _ModelUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
