# hackathon_project

NovaWorks CRM — Flutter app with Firebase backend and AI-powered project creation.

## AI project generation (Gemini)

The Gemini API key is **never shipped to the client**. The app calls the
`generateProjects` Cloud Function (`functions/index.js`), which holds the key
as a secret, verifies the caller is an ADMIN, retries transient failures with
exponential backoff, and deduplicates requests via `requestId`.

### One-time setup

```bash
npm install -g firebase-tools
firebase login
firebase use test-project-f69c6

cd functions && npm install && cd ..
firebase functions:secrets:set GEMINI_API_KEY   # paste your Gemini key
firebase deploy --only functions
```

Optional: set `GEMINI_MODEL` (defaults to `gemini-3.8-flash`) in a
`functions/.env` file — non-secret env vars are picked up automatically.

The client endpoint defaults to
`https://us-central1-test-project-f69c6.cloudfunctions.net/generateProjects`.
Override at build time with `--dart-define=AI_ENDPOINT=...` if the function is
deployed elsewhere.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
