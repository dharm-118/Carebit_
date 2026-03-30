const defaultScopes = [
  'activity',
  'heartrate',
  'location',
  'nutrition',
  'oxygen_saturation',
  'profile',
  'respiratory_rate',
  'settings',
  'sleep',
  'social',
  'temperature',
  'weight',
];

export const fitbitConfig = {
  clientId: process.env.FITBIT_CLIENT_ID ?? '',
  clientSecret: process.env.FITBIT_CLIENT_SECRET ?? '',
  redirectUri: process.env.FITBIT_REDIRECT_URI ?? '',
  scopes: (
    process.env.FITBIT_SCOPES ??
    defaultScopes.join(' ')
  )
    .split(/\s+/)
    .filter(Boolean),
};

function isMissingConfigValue(value: string): boolean {
  const normalizedValue = value.trim().toLowerCase();

  if (normalizedValue.length === 0) {
    return true;
  }

  return (
    normalizedValue.startsWith('your_') ||
    normalizedValue.includes('replace_me')
  );
}

export function validateFitbitConfig(): string[] {
  const missing: string[] = [];

  if (isMissingConfigValue(fitbitConfig.clientId)) {
    missing.push('FITBIT_CLIENT_ID');
  }

  if (isMissingConfigValue(fitbitConfig.clientSecret)) {
    missing.push('FITBIT_CLIENT_SECRET');
  }

  if (isMissingConfigValue(fitbitConfig.redirectUri)) {
    missing.push('FITBIT_REDIRECT_URI');
  }

  return missing;
}
