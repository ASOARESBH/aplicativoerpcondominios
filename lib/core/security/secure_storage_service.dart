import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Serviço de armazenamento seguro para o token e os dados da sessão.
///
/// Os dados do morador são persistidos como um único documento JSON. Isso evita
/// várias operações concorrentes no Android Keystore logo após o login, fluxo
/// que pode sobrecarregar dispositivos de entrada e interromper a transição de
/// tela. A leitura dos campos legados permanece para instalações antigas.
class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: AppConstants.keyAuthToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return _storage.read(key: AppConstants.keyAuthToken);
  }

  Future<void> deleteAuthToken() async {
    await _storage.delete(key: AppConstants.keyAuthToken);
  }

  Future<void> saveMoradorData({
    required String moradorId,
    required String nome,
    required String unidade,
    String? email,
  }) async {
    final data = <String, String?>{
      'moradorId': moradorId,
      'nome': nome,
      'unidade': unidade,
      'email': email,
    };
    await _storage.write(
      key: AppConstants.keyMoradorSession,
      value: jsonEncode(data),
    );
  }

  Future<Map<String, String?>> getMoradorData() async {
    final storedSession =
        await _storage.read(key: AppConstants.keyMoradorSession);
    if (storedSession != null && storedSession.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedSession);
        if (decoded is Map) {
          return {
            'moradorId': decoded['moradorId']?.toString(),
            'nome': decoded['nome']?.toString(),
            'unidade': decoded['unidade']?.toString(),
            'email': decoded['email']?.toString(),
          };
        }
      } catch (_) {
        // O fallback abaixo preserva sessões gravadas por versões antigas.
      }
    }

    // Compatibilidade com dados gravados antes da sessão unificada.
    final moradorId = await _storage.read(key: AppConstants.keyMoradorId);
    final nome = await _storage.read(key: AppConstants.keyMoradorNome);
    final unidade = await _storage.read(key: AppConstants.keyMoradorUnidade);
    final email = await _storage.read(key: AppConstants.keyMoradorEmail);
    return {
      'moradorId': moradorId,
      'nome': nome,
      'unidade': unidade,
      'email': email,
    };
  }

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

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<void> clearSession() async {
    // Operações sequenciais preservam estabilidade no Keystore de aparelhos
    // que não lidam bem com exclusões criptográficas em paralelo.
    await _storage.delete(key: AppConstants.keyAuthToken);
    await _storage.delete(key: AppConstants.keyMoradorSession);
    await _storage.delete(key: AppConstants.keyMoradorId);
    await _storage.delete(key: AppConstants.keyMoradorNome);
    await _storage.delete(key: AppConstants.keyMoradorUnidade);
    await _storage.delete(key: AppConstants.keyMoradorEmail);
  }
}
