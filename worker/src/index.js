// NovaWorks AI proxy — Cloudflare Worker (free tier).
// Holds the Gemini API key as a secret, verifies the caller is an ADMIN via
// Firebase Auth, and deduplicates generations by requestId in KV.

const GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta';
const IDENTITY_TOOLKIT_URL =
  'https://identitytoolkit.googleapis.com/v1/accounts:lookup';
const FIRESTORE_BASE =
  'https://firestore.googleapis.com/v1/projects';

const GEMINI_TIMEOUT_MS = 110 * 1000;
const STALE_CLAIM_MS = 6 * 60 * 1000;
const KV_TTL_SECONDS = 60 * 60 * 24 * 7; // keep results for 7 days

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const backoffMs = (attempt) =>
  2000 * Math.pow(3, attempt) + Math.floor(Math.random() * 500);

class UpstreamError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// ---------- Auth ----------

async function verifyIdToken(env, idToken) {
  const res = await fetch(
    `${IDENTITY_TOOLKIT_URL}?key=${env.FIREBASE_WEB_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken }),
    },
  );

  if (!res.ok) return null;

  const data = await res.json();
  const user = data?.users?.[0];

  return user?.localId || null;
}

// Firestore REST: list/get documents. Returns decoded field maps.
function decodeFields(fields = {}) {
  const out = {};

  for (const [key, value] of Object.entries(fields)) {
    if ('stringValue' in value) out[key] = value.stringValue;
    else if ('integerValue' in value) out[key] = Number(value.integerValue);
    else if ('doubleValue' in value) out[key] = value.doubleValue;
    else if ('booleanValue' in value) out[key] = value.booleanValue;
    else if ('timestampValue' in value) out[key] = value.timestampValue;
    else if ('arrayValue' in value) {
      out[key] = (value.arrayValue.values || []).map((v) =>
        'stringValue' in v ? v.stringValue : null,
      );
    } else if ('nullValue' in value) out[key] = null;
  }

  return out;
}

function firestoreUrl(env, path) {
  return `${FIRESTORE_BASE}/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}`;
}

async function firestoreGet(env, idToken, path) {
  const res = await fetch(firestoreUrl(env, path), {
    headers: { Authorization: `Bearer ${idToken}` },
  });

  if (!res.ok) return null;

  const data = await res.json();
  return { id: data.name?.split('/').pop(), ...decodeFields(data.fields) };
}

async function firestoreList(env, idToken, collection) {
  const res = await fetch(`${firestoreUrl(env, collection)}?pageSize=300`, {
    headers: { Authorization: `Bearer ${idToken}` },
  });

  if (!res.ok) return [];

  const data = await res.json();

  return (data.documents || []).map((doc) => ({
    id: doc.name?.split('/').pop(),
    ...decodeFields(doc.fields),
  }));
}

// ---------- Gemini ----------

function buildPrompt(teamDirectory, transcript) {
  return `
You are an expert AI project manager for NovaWorks Technologies.

Convert the supplied meeting transcript into structured project and task data.

EXISTING TEAM DIRECTORY:
${JSON.stringify(teamDirectory)}

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

${transcript}
`;
}

function extractGeminiError(bodyText) {
  try {
    const data = JSON.parse(bodyText);
    return data?.error?.message || 'Gemini request failed.';
  } catch (_) {
    return 'Gemini request failed.';
  }
}

async function callGeminiOnce(env, model, prompt) {
  const res = await fetch(
    `${GEMINI_BASE_URL}/models/${model}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': env.GEMINI_API_KEY,
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.1,
          responseMimeType: 'application/json',
          maxOutputTokens: 16384,
        },
      }),
      signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
    },
  );

  if (!res.ok) {
    const bodyText = await res.text();
    throw new UpstreamError(res.status, extractGeminiError(bodyText));
  }

  return res.json();
}

const isRetryable = (error) =>
  error instanceof UpstreamError
    ? error.status === 429 || error.status >= 500
    : true; // network failures and timeouts

async function tryModelOnce(env, model, prompt) {
  const maxAttempts = 3;
  let lastError;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await callGeminiOnce(env, model, prompt);
    } catch (error) {
      lastError = error;

      const retryable = isRetryable(error);
      const exhausted = attempt === maxAttempts - 1;

      if (!retryable || exhausted) break;

      console.warn(
        `Gemini (${model}) attempt ${attempt + 1} failed ` +
        `(${error.message || error}); retrying.`,
      );
      await sleep(backoffMs(attempt));
    }
  }

  throw lastError;
}

async function generateWithGemini(env, prompt) {
  const models = [env.GEMINI_MODEL || 'gemini-3.8-flash',
    env.GEMINI_FALLBACK_MODEL || 'gemini-flash-latest']
    .filter((m, i, all) => all.indexOf(m) === i);

  let lastError;

  for (const model of models) {
    try {
      return await tryModelOnce(env, model, prompt);
    } catch (error) {
      lastError = error;

      const shouldFallback = error instanceof UpstreamError &&
        (error.status === 404 || error.status >= 500);

      if (!shouldFallback) throw error;

      console.warn(
        `Gemini model "${model}" unavailable (${error.message}); ` +
        'trying fallback model.',
      );
    }
  }

  throw lastError;
}

function extractGeneratedJson(responseData) {
  const candidates = responseData?.candidates;

  if (!Array.isArray(candidates) || candidates.length === 0) {
    const blockReason = responseData?.promptFeedback?.blockReason;
    throw new Error(
      blockReason
        ? `Gemini blocked the request (${blockReason}).`
        : 'Gemini did not generate a response.',
    );
  }

  const candidate = candidates[0];

  if (candidate?.finishReason === 'MAX_TOKENS') {
    throw new Error('Gemini response was truncated. Try a shorter transcript.');
  }

  const parts = candidate?.content?.parts;

  if (!Array.isArray(parts)) {
    throw new Error('Gemini returned an invalid response structure.');
  }

  const generatedText = parts
    .filter((part) => typeof part?.text === 'string')
    .map((part) => part.text)
    .join('');

  if (!generatedText.trim()) {
    throw new Error('Gemini returned an empty response.');
  }

  let decoded;

  try {
    decoded = JSON.parse(generatedText);
  } catch (_) {
    throw new Error('Gemini returned malformed JSON.');
  }

  if (!decoded || typeof decoded !== 'object' ||
      !Array.isArray(decoded.projects)) {
    throw new Error('Gemini returned an invalid project structure.');
  }

  return decoded;
}

function mapUpstreamError(error) {
  if (error instanceof UpstreamError) {
    switch (error.status) {
      case 400:
        return { status: 400, message: error.message || 'Invalid Gemini request.' };
      case 401:
      case 403:
        return { status: 502, message: 'Gemini rejected the server API key.' };
      case 404:
        return { status: 502, message: 'Gemini model is unavailable.' };
      case 429:
        return { status: 429, message: 'Gemini rate limit reached. Please retry shortly.' };
      case 503:
        return { status: 503, message: 'Gemini is temporarily unavailable. Please retry.' };
      default:
        return { status: 502, message: error.message || 'Gemini request failed.' };
    }
  }

  const name = error?.name || '';
  if (name === 'TimeoutError' || name === 'AbortError') {
    return { status: 504, message: 'Gemini request timed out. Please retry.' };
  }

  return { status: 502, message: 'Could not reach Gemini. Please retry.' };
}

// ---------- Idempotency (KV) ----------

async function claimRequest(env, requestId, uid) {
  const key = `gen:${requestId}`;
  const existing = await env.AI_REQUESTS.get(key, 'json');

  if (existing) {
    if (existing.status === 'completed') {
      return { kind: 'completed', result: existing.result };
    }

    const updatedAt = existing.updatedAt || 0;
    const isFresh = Date.now() - updatedAt < STALE_CLAIM_MS;

    if (existing.status === 'processing' && isFresh) {
      return { kind: 'conflict' };
    }
    // 'failed' or stale 'processing' -> reclaim below.
  }

  await env.AI_REQUESTS.put(key, JSON.stringify({
    status: 'processing',
    uid,
    updatedAt: Date.now(),
  }), { expirationTtl: KV_TTL_SECONDS });

  return { kind: 'claimed' };
}

async function finishRequest(env, requestId, uid, payload) {
  await env.AI_REQUESTS.put(`gen:${requestId}`, JSON.stringify({
    ...payload,
    uid,
    updatedAt: Date.now(),
  }), { expirationTtl: KV_TTL_SECONDS });
}

// ---------- Entry ----------

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed.' }, 405);
    }

    // --- Auth ---
    const authHeader = request.headers.get('Authorization') || '';
    const idToken = authHeader.startsWith('Bearer ')
      ? authHeader.slice(7)
      : null;

    if (!idToken) {
      return json({ error: 'Missing authentication token.' }, 401);
    }

    let uid;

    try {
      uid = await verifyIdToken(env, idToken);
    } catch (_) {
      uid = null;
    }

    if (!uid) {
      return json({ error: 'Invalid authentication token.' }, 401);
    }

    // --- Admin check (Firestore security rules allow users to read
    // signed-in user docs; the ID token satisfies request.auth) ---
    let user;

    try {
      user = await firestoreGet(env, idToken, `users/${uid}`);
    } catch (_) {
      user = null;
    }

    if (user?.role !== 'ADMIN') {
      return json({ error: 'Only administrators can create projects.' }, 403);
    }

    // --- Input ---
    let body;

    try {
      body = await request.json();
    } catch (_) {
      body = null;
    }

    const transcript = typeof body?.transcript === 'string'
      ? body.transcript.trim()
      : '';
    const requestId = typeof body?.requestId === 'string'
      ? body.requestId.trim()
      : '';

    if (!transcript) {
      return json({ error: 'Please enter the meeting transcript.' }, 400);
    }

    if (!requestId || requestId.length > 128) {
      return json({ error: 'Missing or invalid requestId.' }, 400);
    }

    if (!env.GEMINI_API_KEY) {
      return json({ error: 'AI service is not configured.' }, 500);
    }

    // --- Idempotency ---
    let claim;

    try {
      claim = await claimRequest(env, requestId, uid);
    } catch (_) {
      // KV unavailable: proceed without dedup rather than blocking users.
      claim = { kind: 'claimed' };
    }

    if (claim.kind === 'completed') {
      return json(claim.result);
    }

    if (claim.kind === 'conflict') {
      return json({
        error: 'This generation is already in progress. Please wait and retry.',
      }, 409);
    }

    // --- Generate ---
    try {
      const members = await firestoreList(env, idToken, 'users');

      const teamDirectory = members.map((m) => ({
        employeeCode: m.employeeCode || m.id,
        name: m.name || '',
        role: m.role || '',
        specialization: m.specialization || '',
        skills: m.skills || [],
      }));

      const prompt = buildPrompt(teamDirectory, transcript);
      const geminiResponse = await generateWithGemini(env, prompt);
      const result = extractGeneratedJson(geminiResponse);

      try {
        await finishRequest(env, requestId, uid, {
          status: 'completed',
          result,
        });
      } catch (_) {
        // KV write failure is non-fatal.
      }

      return json(result);
    } catch (error) {
      console.error('generateProjects failed:', error?.message || error);

      try {
        await finishRequest(env, requestId, uid, {
          status: 'failed',
          error: error?.message || 'Generation failed.',
        });
      } catch (_) {
        // ignore
      }

      const mapped = mapUpstreamError(error);
      return json({ error: mapped.message }, mapped.status);
    }
  },
};
