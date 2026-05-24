class AppConstants {
  AppConstants._();

  // Supabase
  static const String supabaseUrl = 'https://yxdwshujxsnamnmllljc.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_ewJwkoSbTSQ-q49QUMGgbg_JqVqtF6b';

  // Edge Functions
  static String get edgeFunctionsUrl => '$supabaseUrl/functions/v1';
  static String get generateQrUrl => '$edgeFunctionsUrl/generate-qr';
  static String get validateQrUrl => '$edgeFunctionsUrl/validate-qr';
  static String get confirmAccessUrl => '$edgeFunctionsUrl/confirm-access';

  // App
  static const String appName = 'Nimbus';
  static const int qrDefaultExpirationHours = 24;
}

