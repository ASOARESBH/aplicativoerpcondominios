import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Serviço de armazenamento seguro para dados sensíveis (token, credenciais).
///
/// NOTA: A URL base não é mais armazenada aqui.
/// O sistema usa URL FIXA: [AppConstants.baseUrl]
/// O tenant é identificado pelo token Bearer, não pela URL.
class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ─── Token / Auth ──────────────────────────────────────────────────────────

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: AppConstants.keyAuthToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: AppConstants.keyAuthToken);
  }

  Future<void> deleteAuthToken() async {
    await _storage.delete(key: AppConstants.keyAuthToken);
  }

  // ─── Morador Data ──────────────────────────────────────────────────────────

  Future<void> saveMoradorData({
    required String moradorId,
    required String nome,
    required String unidade,
    String? email,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyMoradorId, value: moradorId),
      _storage.write(key: AppConstants.keyMoradorNome, value: nome),
      _storage.write(key: AppConstants.keyMoradorUnidade, value: unidade),
      if (email != null)
        _storage.write(key: AppConstants.keyMoradorEmail, value: email),
    ]);
  }

  Future<Map<String, String?>> getMoradorData() async {
    final results = await Future.wait([
      _storage.read(key: AppConstants.keyMoradorId),
      _storage.read(key: AppConstants.keyMoradorNome),
      _storage.read(key: AppConstants.keyMoradorUnidade),
      _storage.read(key: AppConstants.keyMoradorEmail),
    ]);
    return {
      'moradorId': results[0],
      'nome':      results[1],
      'unidade':   results[2],
      'email':     results[3],
    };
  }

  // ─── Preferências ─────────────────────────────────────────────────────────

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: AppConstants.keyBiometricEnabled,
      value: enabled ? '1' : '0',
    );
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: AppConstants.keyBiometricEnabled);
    return val == '1';
  }

  Future<void> setDarkMode(bool enabled) async {
    await _storage.write(
      key: AppConstants.keyDarkMode,
      value: enabled ? '1' : '0',
    );
  }

  Future<bool> isDarkMode() async {
    final val = await _storage.read(key: AppConstants.keyDarkMode);
    return val == '1';
  }

  // ─── Limpeza ──────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: AppConstants.keyAuthToken),
      _storage.delete(key: AppConstants.keyMoradorId),
      _storage.delete(key: AppConstants.keyMoradorNome),
      _storage.delete(key: AppConstants.keyMoradorUnidade),
      _storage.delete(key: AppConstants.keyMoradorEmail),
    ]);
  }
}
