import { fitbitConfig } from '../config/fitbit_config';

const fitbitAuthBaseUrl = 'https://www.fitbit.com/oauth2/authorize';
const fitbitTokenUrl = 'https://api.fitbit.com/oauth2/token';
const fitbitApiBaseUrl = 'https://api.fitbit.com';

type FitbitErrorPayload = {
  errors?: Array<{ errorType?: string; message?: string }>;
  success?: boolean;
};

export type FitbitTokenResponse = {
  access_token: string;
  expires_in: number;
  refresh_token: string;
  scope: string;
  token_type: string;
  user_id: string;
};

export type FitbitDevicePayload = {
  battery: string | null;
  batteryLevel: number | null;
  deviceId: string;
  deviceName: string;
  deviceType: string | null;
  lastSyncTime: string | null;
  macAddress: string | null;
  rawPayload: Record<string, unknown>;
};

function asRecord(value: unknown): Record<string, unknown> | null {
  if (typeof value !== 'object' || value == null || Array.isArray(value)) {
    return null;
  }

  return value as Record<string, unknown>;
}

function asString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalizedValue = value.trim();
  return normalizedValue.length === 0 ? null : normalizedValue;
}

function asNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === 'string') {
    const parsedValue = Number.parseFloat(value);
    return Number.isFinite(parsedValue) ? parsedValue : null;
  }

  return null;
}

function parseLastSyncTime(value: string | null): number {
  if (value == null) {
    return 0;
  }

  const parsedTimestamp = Date.parse(value);
  return Number.isNaN(parsedTimestamp) ? 0 : parsedTimestamp;
}

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

export function selectPrimaryFitbitDevice(
  devicesPayload: unknown,
): FitbitDevicePayload | null {
  if (!Array.isArray(devicesPayload)) {
    return null;
  }

  const normalizedDevices = devicesPayload
    .map((entry) => {
      const rawPayload = asRecord(entry);
      if (rawPayload == null) {
        return null;
      }

      const deviceId =
        asString(rawPayload.id) ?? asString(rawPayload.deviceId) ?? null;
      if (deviceId == null) {
        return null;
      }

      const deviceType = asString(rawPayload.type);
      const deviceName =
        asString(rawPayload.deviceVersion) ??
        deviceType ??
        `Fitbit device ${deviceId}`;

      return {
        battery: asString(rawPayload.battery),
        batteryLevel: asNumber(rawPayload.batteryLevel),
        deviceId,
        deviceName,
        deviceType,
        lastSyncTime: asString(rawPayload.lastSyncTime),
        macAddress: asString(rawPayload.mac),
        rawPayload,
      };
    })
    .filter((device): device is FitbitDevicePayload => device != null);

  if (normalizedDevices.length === 0) {
    return null;
  }

  normalizedDevices.sort((left, right) => {
    // Prefer the most recently synced device, then fall back to a stable ID sort.
    const syncDelta =
      parseLastSyncTime(right.lastSyncTime) -
      parseLastSyncTime(left.lastSyncTime);

    if (syncDelta !== 0) {
      return syncDelta;
    }

    return left.deviceId.localeCompare(right.deviceId);
  });

  return normalizedDevices[0];
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
