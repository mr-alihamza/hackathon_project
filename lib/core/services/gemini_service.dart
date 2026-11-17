import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/models/user_model.dart';

class GeminiService {
  String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];

    if (key == null || key.trim().isEmpty) {
      throw Exception('Gemini API key is missing.');
    }

    return key.trim();
  }

  String get _model => dotenv.env['GEMINI_MODEL'] ?? 'gemini-3.8-flash';

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

    final prompt =
        '''
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

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$_model:generateContent?key=$_apiKey',
    );

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
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
              'maxOutputTokens': 8192,
            },
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body));
    }

    final responseData = jsonDecode(response.body);

    final candidates = responseData['candidates'] as List?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini did not generate a response.');
    }

    final parts = candidates.first['content']['parts'] as List;

    final generatedText = parts
        .where((part) => part['text'] != null)
        .map((part) => part['text'].toString())
        .join();

    if (generatedText.trim().isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    final decoded = jsonDecode(generatedText);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Gemini returned an invalid JSON structure.');
    }

    if (decoded['projects'] is! List) {
      throw Exception('Generated projects are missing.');
    }

    return decoded;
  }

  String _extractError(String body) {
    try {
      final data = jsonDecode(body);
      return data['error']?['message'] ?? 'Gemini request failed.';
    } catch (_) {
      return 'Gemini request failed. Please try again.';
    }
  }
}
