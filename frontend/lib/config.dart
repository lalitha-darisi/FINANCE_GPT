const String baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8000', // fallback if no dart-define used
);
