abstract final class AppConfig {
  static const marketApiBaseUrl = String.fromEnvironment(
    'FINOTE_MARKET_API_BASE_URL',
    defaultValue: 'https://43.157.243.246/',
  );
}
