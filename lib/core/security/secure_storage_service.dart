import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Serviço de armazenamento seguro para dados sensíveis (token, credenciais)
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
    required String email,
    String? tenantId,
    bool senhaTemporaria = false,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyMoradorId, value: moradorId),
      _storage.write(key: AppConstants.keyMoradorNome, value: nome),
      _storage.write(key: AppConstants.keyMoradorUnidade, value: unidade),
      _storage.write(key: AppConstants.keyMoradorEmail, value: email),
      if (tenantId != null)
        _storage.write(key: AppConstants.keyTenantId, value: tenantId),
      _storage.write(
        key: AppConstants.keySenhaTemporaria,
        value: senhaTemporaria ? '1' : '0',
      ),
    ]);
  }

  Future<Map<String, String?>> getMoradorData() async {
    final results = await Future.wait([
      _storage.read(key: AppConstants.keyMoradorId),
      _storage.read(key: AppConstants.keyMoradorNome),
      _storage.read(key: AppConstants.keyMoradorUnidade),
      _storage.read(key: AppConstants.keyMoradorEmail),
      _storage.read(key: AppConstants.keyTenantId),
      _storage.read(key: AppConstants.keySenhaTemporaria),
    ]);
    return {
      'moradorId': results[0],
      'nome': results[1],
      'unidade': results[2],
      'email': results[3],
      'tenantId': results[4],
      'senhaTemporaria': results[5],
    };
  }

  // ─── Base URL (Multi-Tenant) ───────────────────────────────────────────────

  Future<void> saveBaseUrl(String url) async {
    await _storage.write(key: AppConstants.keyBaseUrl, value: url);
  }

  Future<String> getBaseUrl() async {
    final url = await _storage.read(key: AppConstants.keyBaseUrl);
    return url ?? AppConstants.defaultBaseUrl;
  }

  // ─── Preferences ──────────────────────────────────────────────────────────

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

  // ─── Clear All ────────────────────────────────────────────────────────────

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
      _storage.delete(key: AppConstants.keyTenantId),
      _storage.delete(key: AppConstants.keySenhaTemporaria),
    ]);
  }
}
