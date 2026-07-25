import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Serviço de autenticação biométrica (Face ID / Touch ID / Impressão Digital)
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Verifica se o dispositivo suporta biometria
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Retorna os tipos de biometria disponíveis
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Autentica com biometria
  Future<bool> authenticate({
    String reason = 'Confirme sua identidade para acessar o ERP Condomínios',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      // Log error
      print('[BiometricService] Error: ${e.code} - ${e.message}');
      return false;
    }
  }

  /// Retorna o nome amigável do tipo de biometria disponível
  Future<String> getBiometricLabel() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) return 'Face ID';
    if (biometrics.contains(BiometricType.fingerprint)) return 'Impressão Digital';
    if (biometrics.contains(BiometricType.iris)) return 'Íris';
    return 'Biometria';
  }
}
