import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Serviço de notificações locais e push (Firebase Cloud Messaging)
/// 
/// Nota: A integração completa com Firebase requer configuração de
/// google-services.json (Android) e GoogleService-Info.plist (iOS)
/// que devem ser adicionados pelo desenvolvedor antes da publicação.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Inicializa o serviço de notificações
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
    // TODO: Navigate to the appropriate screen based on payload
  }

  /// Exibe uma notificação local
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'erp_condominios',
    String channelName = 'ERP Condomínios',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notificações do ERP Condomínios',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Cancela uma notificação específica
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancela todas as notificações
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  void debugPrint(String message) {
    // ignore: avoid_print
    print(message);
  }
}

/// Canais de notificação por módulo
class NotificationChannels {
  static const String boletos = 'boletos';
  static const String comunicados = 'comunicados';
  static const String visitantes = 'visitantes';
  static const String correspondencias = 'correspondencias';
  static const String chamados = 'chamados';
  static const String agua = 'agua';
  static const String documentos = 'documentos';
  static const String geral = 'erp_condominios';
}
