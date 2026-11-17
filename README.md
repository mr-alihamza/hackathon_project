# hackathon_project

NovaWorks CRM — Flutter app with Firebase backend and AI-powered project creation.

## AI project generation (Gemini)

The Gemini API key is **never shipped to the client**. The app calls a
Cloudflare Worker proxy (`worker/`), which holds the key as a secret, verifies
the caller is an ADMIN via Firebase Auth, retries transient failures with
exponential backoff + model fallback, and deduplicates requests by `requestId`
in KV storage. (A `functions/` Cloud Function version is also included if you
ever upgrade to the Blaze plan.)

### Deploy the worker (free tier)

```bash
cd worker
npm install
npx wrangler login
npx wrangler kv namespace create AI_REQUESTS   # copy the id into wrangler.toml
npx wrangler secret put GEMINI_API_KEY        # paste your Gemini key
npm run deploy
```

Then set the worker URL in `lib/core/services/gemini_service.dart`
(`AI_ENDPOINT` dart-define or the `defaultValue`).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
