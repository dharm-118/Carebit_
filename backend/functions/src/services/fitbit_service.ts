import { fitbitConfig } from '../config/fitbit_config';

const fitbitAuthBaseUrl = 'https://www.fitbit.com/oauth2/authorize';
const fitbitTokenUrl = 'https://api.fitbit.com/oauth2/token';
const fitbitApiBaseUrl = 'https://api.fitbit.com';

type FitbitErrorPayload = {
  errors?: Array<{ errorType?: string; message?: string }>;
  success?: boolean;
};

type FitbitTokenResponse = {
  access_token: string;
  expires_in: number;
  refresh_token: string;
  scope: string;
  token_type: string;
  user_id: string;
};

function buildBasicAuthHeader(): string {
  const credentials = `${fitbitConfig.clientId}:${fitbitConfig.clientSecret}`;
  return `Basic ${Buffer.from(credentials).toString('base64')}`;
}

async function parseFitbitResponse<T>(response: Response): Promise<T> {
  const responseText = await response.text();
  const payload = responseText
    ? (JSON.parse(responseText) as T & FitbitErrorPayload)
    : ({} as T & FitbitErrorPayload);

  if (!response.ok) {
    const errorMessage =
      payload.errors?.map((error) => error.message).filter(Boolean).join('; ') ||
      `Fitbit request failed with status ${response.status}`;

    throw new Error(errorMessage);
  }

  return payload;
}

async function fetchFitbitJson<T>(
  path: string,
  accessToken: string,
): Promise<T> {
  const response = await fetch(`${fitbitApiBaseUrl}${path}`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
    },
  });

  return parseFitbitResponse<T>(response);
}

async function safeFetch<T>(
  path: string,
  accessToken: string,
): Promise<{ data: T | null; error: string | null }> {
  try {
    const data = await fetchFitbitJson<T>(path, accessToken);
    return { data, error: null };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Unknown Fitbit API error';

    return { data: null, error: message };
  }
}

export function buildFitbitAuthorizationUrl(state?: string): string {
  const searchParams = new URLSearchParams({
    client_id: fitbitConfig.clientId,
    redirect_uri: fitbitConfig.redirectUri,
    prompt: 'login consent',
    response_type: 'code',
    scope: fitbitConfig.scopes.join(' '),
  });

  if (state) {
    searchParams.set('state', state);
  }

  return `${fitbitAuthBaseUrl}?${searchParams.toString()}`;
}

export async function exchangeCodeForTokens(
  code: string,
): Promise<FitbitTokenResponse> {
  const response = await fetch(fitbitTokenUrl, {
    method: 'POST',
    headers: {
      Authorization: buildBasicAuthHeader(),
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      code,
      grant_type: 'authorization_code',
      redirect_uri: fitbitConfig.redirectUri,
    }),
  });

  return parseFitbitResponse<FitbitTokenResponse>(response);
}

export async function fetchFitbitDevices(accessToken: string): Promise<unknown> {
  return fetchFitbitJson('/1/user/-/devices.json', accessToken);
}

export async function fetchFitbitHealthMetrics(
  accessToken: string,
): Promise<{
  profile: unknown | null;
  heartRate: unknown | null;
  sleep: unknown | null;
  oxygenSaturation: unknown | null;
  errors: Record<string, string>;
}> {
  const [profile, heartRate, sleep, oxygenSaturation] = await Promise.all([
    safeFetch('/1/user/-/profile.json', accessToken),
    safeFetch('/1/user/-/activities/heart/date/today/1d.json', accessToken),
    safeFetch('/1.2/user/-/sleep/date/today.json', accessToken),
    safeFetch('/1/user/-/spo2/date/today.json', accessToken),
  ]);

  const errors: Record<string, string> = {};

  if (profile.error != null) {
    errors.profile = profile.error;
  }

  if (heartRate.error != null) {
    errors.heartRate = heartRate.error;
  }

  if (sleep.error != null) {
    errors.sleep = sleep.error;
  }

  if (oxygenSaturation.error != null) {
    errors.oxygenSaturation = oxygenSaturation.error;
  }

  return {
    profile: profile.data,
    heartRate: heartRate.data,
    sleep: sleep.data,
    oxygenSaturation: oxygenSaturation.data,
    errors,
  };
}
