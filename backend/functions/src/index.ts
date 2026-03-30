import { initializeApp } from 'firebase-admin/app';
import { onRequest } from 'firebase-functions/v2/https';
import type { Request, Response } from 'express';

import { fitbitConfig, validateFitbitConfig } from './config/fitbit_config';
import {
  buildFitbitAuthorizationUrl,
  exchangeCodeForTokens,
  fetchFitbitDevices,
  fetchFitbitHealthMetrics,
} from './services/fitbit_service';

initializeApp();

function sendConfigErrorResponse(response: Response): boolean {
  const missing = validateFitbitConfig();

  if (missing.length === 0) {
    return false;
  }

  response.status(500).json({
    ok: false,
    error: 'Fitbit backend configuration is incomplete.',
    missing,
  });

  return true;
}

function readAccessToken(request: Request): string | null {
  const authorizationHeader = request.get('authorization');

  if (authorizationHeader?.startsWith('Bearer ')) {
    return authorizationHeader.slice('Bearer '.length).trim();
  }

  const queryToken = request.query.accessToken;

  if (typeof queryToken === 'string' && queryToken.trim().length > 0) {
    return queryToken.trim();
  }

  return null;
}

export const health = onRequest((request, response) => {
  response.json({
    ok: true,
    service: 'carebit-functions',
    method: request.method,
    fitbitConfigured: validateFitbitConfig().length === 0,
  });
});

export const fitbitAuthStart = onRequest((request, response) => {
  if (sendConfigErrorResponse(response)) {
    return;
  }

  const state =
    typeof request.query.state === 'string' ? request.query.state : undefined;
  const mode = typeof request.query.mode === 'string' ? request.query.mode : '';
  const authUrl = buildFitbitAuthorizationUrl(state);

  if (mode.toLowerCase() === 'json') {
    response.json({
      ok: true,
      authUrl,
      redirectUri: fitbitConfig.redirectUri,
      scopes: fitbitConfig.scopes,
    });
    return;
  }

  response.redirect(authUrl);
});

export const fitbitAuthCallback = onRequest(async (request, response) => {
  if (sendConfigErrorResponse(response)) {
    return;
  }

  const error = request.query.error;
  if (typeof error === 'string') {
    response.status(400).json({
      ok: false,
      error,
      errorDescription:
        typeof request.query.error_description === 'string'
          ? request.query.error_description
          : null,
    });
    return;
  }

  const code = request.query.code;
  if (typeof code !== 'string' || code.trim() === '') {
    const state =
      typeof request.query.state === 'string' ? request.query.state : undefined;
    const mode =
      typeof request.query.mode === 'string' ? request.query.mode : '';
    const authUrl = buildFitbitAuthorizationUrl(state);

    if (mode.toLowerCase() === 'json') {
      response.status(400).json({
        ok: false,
        error: 'Missing Fitbit authorization code.',
        authUrl,
      });
      return;
    }

    response.redirect(authUrl);
    return;
  }

  try {
    const tokenResponse = await exchangeCodeForTokens(code);
    response.json({
      ok: true,
      token: tokenResponse,
    });
  } catch (err) {
    response.status(500).json({
      ok: false,
      error: err instanceof Error ? err.message : 'Fitbit token exchange failed.',
    });
  }
});

export const fitbitDevices = onRequest(async (request, response) => {
  const accessToken = readAccessToken(request);

  if (accessToken == null) {
    response.status(400).json({
      ok: false,
      error:
        'Missing Fitbit access token. Pass it as Authorization: Bearer <token> or ?accessToken=<token>.',
    });
    return;
  }

  try {
    const devices = await fetchFitbitDevices(accessToken);
    response.json({
      ok: true,
      devices,
    });
  } catch (err) {
    response.status(500).json({
      ok: false,
      error: err instanceof Error ? err.message : 'Failed to fetch Fitbit devices.',
    });
  }
});

export const fitbitHealthMetrics = onRequest(async (request, response) => {
  const accessToken = readAccessToken(request);

  if (accessToken == null) {
    response.status(400).json({
      ok: false,
      error:
        'Missing Fitbit access token. Pass it as Authorization: Bearer <token> or ?accessToken=<token>.',
    });
    return;
  }

  try {
    const metrics = await fetchFitbitHealthMetrics(accessToken);
    response.json({
      ok: true,
      metrics,
    });
  } catch (err) {
    response.status(500).json({
      ok: false,
      error:
        err instanceof Error ? err.message : 'Failed to fetch Fitbit health metrics.',
    });
  }
});
