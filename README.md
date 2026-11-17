# hackathon_project

NovaWorks CRM — Flutter app with Firebase backend and AI-powered project creation.

## AI project generation (Gemini)

The app calls the Gemini API directly via `lib/core/services/gemini_service.dart`.
Configuration lives in the `.env` file (bundled as an asset, git-ignored):

```
GEMINI_API_KEY=...   # from Google AI Studio
GEMINI_MODEL=gemini-3.8-flash
```

The service retries transient failures (429/5xx, network errors, timeouts)
with exponential backoff, falls back to `gemini-flash-latest` if the
configured model is unavailable, sends the API key in a header (not the URL),
and validates the generated JSON before anything is saved to Firestore.

NOTE: the API key ships inside the app binary. Restrict and rotate it in
Google AI Studio if the app is distributed.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
