const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

const geminiApiKey = defineSecret('GEMINI_API_KEY');

const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-3.8-flash';
// Fallback models tried (in order) when the primary is unavailable.
const GEMINI_FALLBACK_MODELS = ['gemini-flash-latest'];
const GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta';

// Per-attempt timeout for a single Gemini request.
const GEMINI_TIMEOUT_MS = 110 * 1000;
// A 'processing' claim older than this is considered stale and may be retried.
const STALE_CLAIM_MS = 6 * 60 * 1000;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};

function sendJson(res, status, payload) {
  res.set(CORS_HEADERS);
  res.status(status).json(payload);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function backoffMs(attempt) {
  // Exponential backoff: 2s, 6s, 18s...
  return 2000 * Math.pow(3, attempt) + Math.floor(Math.random() * 500);
}

class UpstreamError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

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

async function getTeamDirectory() {
  const snapshot = await db.collection('users').get();

  return snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      employeeCode: data.employeeCode || doc.id,
      name: data.name || '',
      role: data.role || '',
      specialization: data.specialization || '',
      skills: data.skills || [],
    };
  });
}

function extractGeminiError(bodyText) {
  try {
    const data = JSON.parse(bodyText);
    return data?.error?.message || 'Gemini request failed.';
  } catch (_) {
    return 'Gemini request failed.';
  }
}

async function callGeminiOnce(model, prompt) {
  const url = `${GEMINI_BASE_URL}/models/${model}:generateContent`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      // API key in a header keeps it out of URLs and access logs.
      'x-goog-api-key': geminiApiKey.value(),
    },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: 'application/json',
        // Gemini 3.x is a thinking model; leave headroom for reasoning tokens.
        maxOutputTokens: 16384,
      },
    }),
    signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
  });

  if (!response.ok) {
    const bodyText = await response.text();
    throw new UpstreamError(response.status, extractGeminiError(bodyText));
  }

  return response.json();
}

function isRetryable(error) {
  if (error instanceof UpstreamError) {
    return error.status === 429 || error.status >= 500;
  }
  // Network failures and timeouts (AbortError / TimeoutError / fetch errors).
  return true;
}

async function tryModelOnce(model, prompt) {
  const maxAttempts = 3;
  let lastError;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await callGeminiOnce(model, prompt);
    } catch (error) {
      lastError = error;

      const retryable = isRetryable(error);
      const exhausted = attempt === maxAttempts - 1;

      if (!retryable || exhausted) {
        break;
      }

      console.warn(
        `Gemini (${model}) attempt ${attempt + 1} failed ` +
        `(${error.message || error}); retrying.`,
      );
      await sleep(backoffMs(attempt));
    }
  }

  throw lastError;
}

async function generateWithGemini(prompt) {
  const models = [GEMINI_MODEL, ...GEMINI_FALLBACK_MODELS]
    .filter((model, index, all) => all.indexOf(model) === index);

  let lastError;

  for (const model of models) {
    try {
      return await tryModelOnce(model, prompt);
    } catch (error) {
      lastError = error;

      const shouldFallback = error instanceof UpstreamError &&
        (error.status === 404 || error.status === 503 ||
          error.status >= 500);

      if (!shouldFallback) {
        throw error;
      }

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
  const finishReason = candidate?.finishReason;

  if (finishReason === 'MAX_TOKENS') {
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

  if (!decoded || typeof decoded !== 'object' || !Array.isArray(decoded.projects)) {
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
        return { status: 502, message: `Gemini model "${GEMINI_MODEL}" is unavailable.` };
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

exports.generateProjects = onRequest(
  {
    region: 'us-central1',
    timeoutSeconds: 1800,
    memory: '512MiB',
    secrets: [geminiApiKey],
  },
  async (req, res) => {
    res.set(CORS_HEADERS);

    if (req.method === 'OPTIONS') {
      res.status(204).end();
      return;
    }

    if (req.method !== 'POST') {
      sendJson(res, 405, { error: 'Method not allowed.' });
      return;
    }

    // --- Authenticate the caller ---
    const authHeader = req.get('Authorization') || '';
    const idToken = authHeader.startsWith('Bearer ')
      ? authHeader.slice(7)
      : null;

    if (!idToken) {
      sendJson(res, 401, { error: 'Missing authentication token.' });
      return;
    }

    let uid;

    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      uid = decoded.uid;
    } catch (_) {
      sendJson(res, 401, { error: 'Invalid authentication token.' });
      return;
    }

    // --- Only admins may generate projects ---
    const userSnap = await db.collection('users').doc(uid).get();
    const role = userSnap.data()?.role;

    if (role !== 'ADMIN') {
      sendJson(res, 403, { error: 'Only administrators can create projects.' });
      return;
    }

    // --- Validate input ---
    const transcript = typeof req.body?.transcript === 'string'
      ? req.body.transcript.trim()
      : '';

    const requestId = typeof req.body?.requestId === 'string'
      ? req.body.requestId.trim()
      : '';

    if (!transcript) {
      sendJson(res, 400, { error: 'Please enter the meeting transcript.' });
      return;
    }

    if (!requestId || requestId.length > 128) {
      sendJson(res, 400, { error: 'Missing or invalid requestId.' });
      return;
    }

    // --- Idempotency: one generation per requestId ---
    const requestRef = db.collection('aiRequests').doc(requestId);

    const claim = await db.runTransaction(async (tx) => {
      const snap = await tx.get(requestRef);

      if (snap.exists) {
        const data = snap.data();

        if (data.status === 'completed') {
          return { kind: 'completed', result: data.result };
        }

        const updatedAt = data.updatedAt?.toMillis?.() || 0;
        const isFresh = Date.now() - updatedAt < STALE_CLAIM_MS;

        if (data.status === 'processing' && isFresh) {
          return { kind: 'conflict' };
        }
        // 'failed' or stale 'processing' -> reclaim below.
      }

      tx.set(requestRef, {
        status: 'processing',
        uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { kind: 'claimed' };
    });

    if (claim.kind === 'completed') {
      sendJson(res, 200, claim.result);
      return;
    }

    if (claim.kind === 'conflict') {
      sendJson(res, 409, {
        error: 'This generation is already in progress. Please wait and retry.',
      });
      return;
    }

    // --- Generate ---
    try {
      const teamDirectory = await getTeamDirectory();
      const prompt = buildPrompt(teamDirectory, transcript);

      const geminiResponse = await generateWithGemini(prompt);
      const result = extractGeneratedJson(geminiResponse);

      await requestRef.set({
        status: 'completed',
        uid,
        result,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      sendJson(res, 200, result);
    } catch (error) {
      console.error('generateProjects failed:', error?.message || error);

      await requestRef.set({
        status: 'failed',
        uid,
        error: error?.message || 'Generation failed.',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const mapped = mapUpstreamError(error);
      sendJson(res, mapped.status, { error: mapped.message });
    }
  },
);
