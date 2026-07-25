import '../../core/errors/app_exceptions.dart';
import '../../core/security/secure_storage_service.dart';
import '../../domain/entities/morador_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';

/// Implementação do repositório de autenticação
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorage;

  AuthRepositoryImpl(this._remoteDataSource, this._secureStorage);

  @override
  Future<MoradorSessionEntity> login({
    required String cpf,
    required String password,
    String? baseUrl,
  }) async {
    final loginResponse = await _remoteDataSource.login(
      cpf: cpf,
      password: password,
      baseUrl: baseUrl,
    );

    if (loginResponse.token == null || loginResponse.moradorId == null) {
      throw const ValidationException('Dados de sessão inválidos.');
    }

    // Salva token no armazenamento seguro
    await _secureStorage.saveAuthToken(loginResponse.token!);
    await _secureStorage.saveMoradorData(
      moradorId: loginResponse.moradorId.toString(),
      nome: loginResponse.nome ?? '',
      unidade: loginResponse.unidade ?? '',
      email: loginResponse.email ?? '',
      senhaTemporaria: loginResponse.senhaTemporaria,
    );

    return MoradorSessionEntity(
      token: loginResponse.token!,
      moradorId: loginResponse.moradorId!,
      nome: loginResponse.nome ?? '',
      unidade: loginResponse.unidade ?? '',
      email: loginResponse.email,
      senhaTemporaria: loginResponse.senhaTemporaria,
    );
  }

  @override
  Future<bool> verifySession() async {
    final token = await _secureStorage.getAuthToken();
    if (token == null || token.isEmpty) return false;
    return await _remoteDataSource.verifySession();
  }

  @override
  Future<void> logout() async {
    await _remoteDataSource.logout();
    await _secureStorage.clearSession();
  }

  @override
  Future<MoradorSessionEntity?> getLocalSession() async {
    final token = await _secureStorage.getAuthToken();
    if (token == null || token.isEmpty) return null;

    final data = await _secureStorage.getMoradorData();
    final moradorIdStr = data['moradorId'];
    if (moradorIdStr == null) return null;

    final moradorId = int.tryParse(moradorIdStr);
    if (moradorId == null) return null;

    return MoradorSessionEntity(
      token: token,
      moradorId: moradorId,
      nome: data['nome'] ?? '',
      unidade: data['unidade'] ?? '',
      email: data['email'],
      tenantId: data['tenantId'],
      senhaTemporaria: data['senhaTemporaria'] == '1',
    );
  }

  @override
  Future<void> requestPasswordRecovery(String email) async {
    await _remoteDataSource.requestPasswordRecovery(email);
  }
}
