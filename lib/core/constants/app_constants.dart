/// Constantes globais do aplicativo ERP Condomínios
///
/// ARQUITETURA MULTI-TENANT:
/// Todas as unidades/condomínios acessam a mesma URL base:
/// https://app.erpcondominios.com.br/
/// O tenant é identificado pelo token de sessão gerado no login.
/// NÃO há configuração de URL por condomínio no app.
class AppConstants {
  AppConstants._();

  // ─── App Info ─────────────────────────────────────────────────────────────
  static const String appName = 'ERP Condomínios';
  static const String appVersion = '1.0.0';
  static const String appPackage = 'br.com.erpcondominios';

  // ─── URL Base FIXA (Multi-Tenant) ─────────────────────────────────────────
  /// URL única para todos os condomínios. Não deve ser alterada pelo usuário.
  static const String baseUrl = 'https://app.erpcondominios.com.br';

  // ─── Endpoints de Autenticação ────────────────────────────────────────────
  static const String endpointLogin = '/api/api_portal.php';
  static const String endpointVerifySession = '/api/api_portal.php';
  static const String endpointLogout = '/api/logout_morador.php';
  static const String endpointPasswordRecovery = '/api/api_recuperar_senha.php';

  // ─── Endpoints do Portal do Morador ──────────────────────────────────────
  static const String endpointPortal = '/api/api_portal_morador.php';
  static const String endpointDependentes = '/api/api_portal_dependentes.php';
  static const String endpointAcessos = '/api/api_acessos_visitantes.php';
  static const String endpointHidrometro = '/api/api_morador_hidrometro.php';
  static const String endpointDocumentos = '/api/api_portal_documentos.php';
  static const String endpointProjetos = '/api/api_portal_projetos.php';
  static const String endpointMarketplace = '/api/api_portal_marketplace.php';
  static const String endpointOS = '/api/api_portal_os.php';
  static const String endpointProtocolos = '/api/api_morador_protocolos.php';
  static const String endpointPushToken = '/api/api_pwa_push.php';
  static const String endpointNotificacoes =
      '/api/api_morador_notificacoes.php';

  // ─── Portal do Colaborador ────────────────────────────────────────────────
  static const String endpointColaborador = '/api/api_colaborador_mobile.php';

  // ─── Actions dos Endpoints ────────────────────────────────────────────────
  // api_portal.php
  static const String actionLogin = 'login';
  static const String actionVerifySession = 'verificar_sessao';

  // api_portal_morador.php
  static const String actionPerfil = 'perfil';
  static const String actionVisitantes = 'visitantes';
  static const String actionVeiculos = 'veiculos';
  static const String actionNotificacoes = 'notificacoes';
  static const String actionMarcarNotificacaoLida = 'marcar_notificacao_lida';
  static const String actionRegistrarTokenPush = 'registrar_token_push';
  static const String actionDesativarTokenPush = 'desativar_token_push';
  static const String actionControleAcesso = 'controle_acesso';

  // api_portal_dependentes.php
  static const String actionListar = 'listar';
  static const String actionCriar = 'criar';
  static const String actionAtualizar = 'atualizar';
  static const String actionExcluir = 'excluir';

  // api_portal_os.php
  static const String actionListarAssuntos = 'listar_assuntos';
  static const String actionAbrirOS = 'abrir';
  static const String actionBuscarOS = 'buscar';
  static const String actionInteracoes = 'listar_interacoes';

  // api_colaborador_mobile.php
  static const String actionLoginColaborador = 'login';
  static const String actionSessaoColaborador = 'sessao';
  static const String actionDashboardColaborador = 'dashboard';
  static const String actionMoradoresColaborador = 'moradores';
  static const String actionAssuntosColaborador = 'assuntos';
  static const String actionChamadosColaborador = 'chamados';
  static const String actionAbrirChamadoColaborador = 'abrir_chamado';
  static const String actionProtocolosColaborador = 'protocolos';
  static const String actionBuscarProtocoloQr = 'buscar_protocolo_qr';
  static const String actionReceberProtocolo = 'receber_protocolo';
  static const String actionEntregarProtocolo = 'entregar_protocolo';
  static const String actionHidrometrosLeiturista = 'hidrometros_leiturista';
  static const String actionFotoHidrometro = 'foto_hidrometro';
  static const String actionRegistrarLeituraHidrometro =
      'registrar_leitura_hidrometro';
  static const String actionVigilanteQrDetalhe = 'vigilante_qr_detalhe';
  static const String actionVigilanteRegistrarLeitura =
      'vigilante_registrar_leitura';
  static const String actionVigilanteHistoricoHoje = 'vigilante_historico_hoje';

  // ─── Storage Keys (Secure Storage) ───────────────────────────────────────
  static const String keyAuthToken = 'portal_token';
  static const String keyMoradorSession = 'morador_session';
  static const String keyMoradorId = 'morador_id';
  static const String keyMoradorNome = 'morador_nome';
  static const String keyMoradorUnidade = 'morador_unidade';
  static const String keyMoradorEmail = 'morador_email';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyDarkMode = 'dark_mode';
  static const String keyColaboradorToken = 'colaborador_token';
  static const String keyColaboradorSession = 'colaborador_session';

  // ─── Session ──────────────────────────────────────────────────────────────
  static const int sessionTimeoutDays = 7;
  static const int maxLoginAttempts = 5;

  // ─── Paginação ────────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;

  // ─── Timeouts de Rede ─────────────────────────────────────────────────────
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;
}
