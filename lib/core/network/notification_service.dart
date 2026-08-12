import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identificação dos canais de alerta mostrados pelo sistema operacional.
class NotificationChannels {
  static const String encomendas = 'encomendas';
  static const String controleAcesso = 'controle_acesso';
  static const String geral = 'erp_condominios';
}

/// Resultado de uma solicitação de alertas no dispositivo.
class DeviceAlertPermissionResult {
  final bool enabled;
  final String? fcmToken;
  final String message;

  const DeviceAlertPermissionResult({
    required this.enabled,
    required this.message,
    this.fcmToken,
  });
}

/// Serviço de notificações locais e push (Firebase Cloud Messaging).
///
/// O histórico de encomendas é sempre buscado na API. O push é opcional:
/// somente é ativado depois que o morador permite alertas no dispositivo.
class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  static const _preferenceDeviceAlerts = 'device_alerts_enabled';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _localInitialized = false;
  bool _firebaseInitialized = false;
  bool _firebaseUnavailable = false;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  void Function(String token)? _onTokenRefresh;

  /// Inicializa o canal local sem solicitar autorização ao usuário.
  Future<void> initialize() async {
    if (_localInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    const channel = AndroidNotificationChannel(
      NotificationChannels.encomendas,
      'Encomendas',
      description: 'Avisos de chegada e entrega de encomendas.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    const accessChannel = AndroidNotificationChannel(
      NotificationChannels.controleAcesso,
      'Controle de Acesso',
      description: 'Avisos de veículos e movimentações de acesso da unidade.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(accessChannel);

    _localInitialized = true;
    debugPrint('[NotificationService] canal local de encomendas inicializado');
  }

  /// Indica se o morador optou por receber banners/sons no aparelho.
  Future<bool> areDeviceAlertsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_preferenceDeviceAlerts) ?? false;
  }

  /// Solicita permissão nativa e prepara o FCM. Não falha se o Firebase ainda
  /// não estiver configurado: a lista interna de notificações continua ativa.
  Future<DeviceAlertPermissionResult> enableDeviceAlerts({
    void Function(String token)? onTokenRefresh,
  }) async {
    await initialize();
    _onTokenRefresh = onTokenRefresh;

    final localPermission = await _requestLocalNotificationPermission();
    if (!localPermission) {
      return const DeviceAlertPermissionResult(
        enabled: false,
        message: 'Permissão de notificações não concedida no aparelho.',
      );
    }

    final firebaseReady = await _initializeFirebase();
    if (!firebaseReady) {
      return const DeviceAlertPermissionResult(
        enabled: false,
        message:
            'O Firebase ainda não está configurado neste aplicativo. As notificações continuam disponíveis na lista interna.',
      );
    }

    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted =
        permission.authorizationStatus == AuthorizationStatus.authorized ||
            permission.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) {
      return const DeviceAlertPermissionResult(
        enabled: false,
        message: 'Permissão de alertas não autorizada.',
      );
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return const DeviceAlertPermissionResult(
        enabled: false,
        message: 'Não foi possível obter o identificador deste dispositivo.',
      );
    }

    await _setDeviceAlertsEnabled(true);
    _listenToTokenRefresh();
    return DeviceAlertPermissionResult(
      enabled: true,
      fcmToken: token,
      message: 'Alertas no dispositivo habilitados.',
    );
  }

  /// Desativa somente a preferência local. O token do servidor é removido
  /// pelo gerenciador após esta chamada.
  Future<void> disableDeviceAlerts() async {
    await _setDeviceAlertsEnabled(false);
  }

  /// Retorna o token atual somente quando o Firebase foi inicializado.
  Future<String?> getCurrentFcmToken() async {
    if (!await _initializeFirebase()) return null;
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> _setDeviceAlertsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceDeviceAlerts, enabled);
  }

  Future<bool> _requestLocalNotificationPermission() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  Future<bool> _initializeFirebase() async {
    if (_firebaseInitialized) return true;
    if (_firebaseUnavailable) return false;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseInitialized = true;
      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
        _showForegroundMessage,
      );
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
      debugPrint('[NotificationService] Firebase Messaging iniciado');
      return true;
    } catch (error) {
      _firebaseUnavailable = true;
      debugPrint('[NotificationService] Firebase indisponível: $error');
      return false;
    }
  }

  void _listenToTokenRefresh() {
    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        if (await areDeviceAlertsEnabled()) {
          _onTokenRefresh?.call(token);
        }
      },
    );
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final title =
        message.notification?.title ?? data['titulo'] ?? 'ERP Condomínios';
    final body = message.notification?.body ??
        data['mensagem'] ??
        'Você tem uma nova notificação.';
    final id = int.tryParse(data['notificacao_id']?.toString() ?? '') ??
        DateTime.now().millisecondsSinceEpoch.remainder(1000000);

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: jsonEncode(data),
      channelId: data['tipo']?.toString() == 'veiculo_cadastrado'
          ? NotificationChannels.controleAcesso
          : (data['tipo']?.toString().contains('mercadoria') == true
              ? NotificationChannels.encomendas
              : NotificationChannels.geral),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    debugPrint('[NotificationService] push aberto: ${message.data}');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint(
        '[NotificationService] notificação local aberta: ${response.payload}');
  }

  /// Exibe uma notificação local, usada quando o app está em primeiro plano.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = NotificationChannels.geral,
  }) async {
    await initialize();
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == NotificationChannels.encomendas
          ? 'Encomendas'
          : (channelId == NotificationChannels.controleAcesso
              ? 'Controle de Acesso'
              : 'ERP Condomínios'),
      channelDescription: channelId == NotificationChannels.encomendas
          ? 'Avisos de chegada e entrega de encomendas.'
          : (channelId == NotificationChannels.controleAcesso
              ? 'Avisos de veículos e movimentações de acesso da unidade.'
              : 'Notificações do ERP Condomínios.'),
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundSubscription = null;
    _tokenRefreshSubscription = null;
  }
}

/// Chamado pelo runtime quando um push de dados chega com o aplicativo em
/// segundo plano. O sistema operacional apresenta a parte `notification` do
/// FCM; este handler garante a inicialização segura do Firebase.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    debugPrint(
        '[NotificationService] push em segundo plano: ${message.messageId}');
  } catch (error) {
    debugPrint(
        '[NotificationService] handler em segundo plano indisponível: $error');
  }
}
