import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/notification_service.dart';
import 'auth_provider.dart';

/// Provider para o serviço de notificações
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Inicializa as notificações e registra o token FCM no servidor
/// 
/// Nota: A integração completa com Firebase requer:
/// 1. Adicionar google-services.json em android/app/
/// 2. Adicionar GoogleService-Info.plist em ios/Runner/
/// 3. Descomentar as importações do firebase_messaging abaixo
/// 4. Executar: flutter pub get
class NotificationManager {
  final NotificationService _notificationService;
  final dynamic _dioClient;

  NotificationManager(this._notificationService, this._dioClient);

  /// Inicializa o serviço de notificações locais
  Future<void> initialize() async {
    await _notificationService.initialize();
  }

  /// Registra o token FCM no servidor ERP
  /// Chamado após o login bem-sucedido
  Future<void> registerFcmToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _dioClient.initBaseUrl();
      await _dioClient.dio.post(
        AppConstants.endpointPushToken,
        data: {
          'action': 'registrar_token',
          'token': token,
          'plataforma': _getPlatform(),
        },
      );
      print('[NotificationManager] FCM token registered: ${token.substring(0, 20)}...');
    } catch (e) {
      print('[NotificationManager] Error registering FCM token: $e');
    }
  }

  /// Remove o token FCM do servidor (no logout)
  Future<void> unregisterFcmToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _dioClient.initBaseUrl();
      await _dioClient.dio.post(
        AppConstants.endpointPushToken,
        data: {
          'action': 'remover_token',
          'token': token,
        },
      );
    } catch (e) {
      print('[NotificationManager] Error unregistering FCM token: $e');
    }
  }

  String _getPlatform() {
    // ignore: avoid_print
    try {
      return 'android'; // Will be detected properly with dart:io
    } catch (_) {
      return 'unknown';
    }
  }
}

final notificationManagerProvider = Provider<NotificationManager>((ref) {
  final notificationService = ref.read(notificationServiceProvider);
  final dioClient = ref.read(dioClientProvider);
  return NotificationManager(notificationService, dioClient);
});
