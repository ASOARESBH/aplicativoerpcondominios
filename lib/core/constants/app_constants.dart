/// Constantes globais do aplicativo ERP Condomínios
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'ERP Condomínios';
  static const String appVersion = '1.0.0';

  // API Base URL (Multi-Tenant: detectado no login)
  static const String defaultBaseUrl = 'https://app.erpcondominios.com.br';

  // API Endpoints
  static const String endpointLogin = '/api/api_portal.php';
  static const String endpointVerifySession = '/api/api_portal.php?action=verificar_sessao';
  static const String endpointLogout = '/api/logout_morador.php';
  static const String endpointProfile = '/api/api_portal_morador.php?action=perfil';
  static const String endpointVisitors = '/api/api_portal_morador.php?action=visitantes';
  static const String endpointHydrometer = '/api/api_portal_morador.php?action=hidrometro';
  static const String endpointVehicles = '/api/api_portal_morador.php?action=veiculos';
  static const String endpointAccess = '/api/api_acessos_visitantes.php';
  static const String endpointDependents = '/api/api_portal_dependentes.php';
  static const String endpointProtocols = '/api/api_morador_protocolos.php';
  static const String endpointDocuments = '/api/api_portal_documentos.php';
  static const String endpointProjects = '/api/api_portal_projetos.php';
  static const String endpointTickets = '/api/api_portal_os.php';
  static const String endpointMarketplace = '/api/api_portal_marketplace.php';
  static const String endpointPushToken = '/api/api_pwa_push.php';
  static const String endpointPasswordRecovery = '/api/api_recuperar_senha.php';

  // Storage Keys (Secure Storage)
  static const String keyAuthToken = 'portal_token';
  static const String keyMoradorId = 'morador_id';
  static const String keyMoradorNome = 'morador_nome';
  static const String keyMoradorUnidade = 'morador_unidade';
  static const String keyMoradorEmail = 'morador_email';
  static const String keyBaseUrl = 'base_url';
  static const String keyTenantId = 'tenant_id';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyDarkMode = 'dark_mode';
  static const String keySenhaTemporaria = 'morador_senha_temporaria';

  // Session
  static const int sessionTimeoutDays = 7;
  static const int maxLoginAttempts = 3;

  // Pagination
  static const int defaultPageSize = 20;

  // Timeouts
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;

  // Colors (hex)
  static const String primaryColor = '#2563EB';
  static const String primaryDarkColor = '#1E40AF';
}
