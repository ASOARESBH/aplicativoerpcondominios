import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/notification_service.dart';
import 'auth_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Coordena a preferência de alertas no dispositivo e o registro seguro do
/// token FCM no Portal do Morador. A lista interna de notificações não depende
/// do Firebase e permanece disponível quando o push estiver desabilitado.
class NotificationManager {
  final NotificationService _notificationService;
  final dynamic _dioClient;

  NotificationManager(this._notificationService, this._dioClient);

  Future<void> initialize() => _notificationService.initialize();

  Future<bool> areDeviceAlertsEnabled() =>
      _notificationService.areDeviceAlertsEnabled();

  Future<DeviceAlertPermissionResult> enableDeviceAlerts() async {
    final result = await _notificationService.enableDeviceAlerts(
      onTokenRefresh: _registerTokenSilently,
    );
    if (!result.enabled || result.fcmToken == null) return result;

    try {
      await _registerToken(result.fcmToken!);
      return result;
    } catch (_) {
      await _notificationService.disableDeviceAlerts();
      return const DeviceAlertPermissionResult(
        enabled: false,
        message:
            'A permissão foi concedida, mas não foi possível vincular este dispositivo à sua conta. Tente novamente.',
      );
    }
  }

  Future<void> disableDeviceAlerts() async {
    final token = await _notificationService.getCurrentFcmToken();
    try {
      if (token != null && token.isNotEmpty) {
        await _dioClient.dio.post(
          AppConstants.endpointPortal,
          queryParameters: {'action': 'desativar_token_push'},
          data: {'fcm_token': token},
        );
      }
    } finally {
      await _notificationService.disableDeviceAlerts();
    }
  }

  /// Deve ser chamado após login ou restauração de sessão. Reativa o token
  /// existente somente se o morador já havia permitido os alertas antes.
  Future<void> syncAfterAuthenticatedSession() async {
    try {
      final enabled = await _notificationService.areDeviceAlertsEnabled();
      if (!enabled) {
        debugPrint('[PushSync] alertas desabilitados; sincronização ignorada');
        return;
      }
      final token = await _notificationService.getCurrentFcmToken();
      if (token == null || token.isEmpty) {
        debugPrint('[PushSync] token FCM indisponível; sincronização adiada');
        return;
      }
      await _registerTokenSilently(token);
      debugPrint('[PushSync] dispositivo sincronizado com sucesso');
    } catch (error) {
      // Push não é requisito para abrir o app; nunca propaga falhas ao login.
      debugPrint('[PushSync] falha isolada: $error');
    }
  }

  Future<void> _registerTokenSilently(String token) async {
    try {
      await _registerToken(token);
    } catch (_) {
      // O token será sincronizado novamente ao reabrir o aplicativo.
    }
  }

  Future<void> _registerToken(String token) async {
    final response = await _dioClient.dio.post(
      AppConstants.endpointPortal,
      queryParameters: {'action': 'registrar_token_push'},
      data: {
        'fcm_token': token,
        'plataforma': _platformName(),
        'device_info': '${AppConstants.appName} ${AppConstants.appVersion}',
      },
    );
    final data = response.data;
    if (data is Map && data['sucesso'] != true) {
      throw Exception(data['mensagem']?.toString() ??
          'Não foi possível registrar o dispositivo.');
    }
  }

  String _platformName() {
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}

final notificationManagerProvider = Provider<NotificationManager>((ref) {
  return NotificationManager(
    ref.read(notificationServiceProvider),
    ref.read(dioClientProvider),
  );
});
