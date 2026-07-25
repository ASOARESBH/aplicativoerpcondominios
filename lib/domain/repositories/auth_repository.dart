import '../entities/morador_entity.dart';

/// Interface do repositório de autenticação
abstract class AuthRepository {
  /// Realiza o login do morador
  /// [cpf] CPF do morador
  /// [password] Senha do morador
  /// [baseUrl] URL base do condomínio (Multi-Tenant)
  Future<MoradorSessionEntity> login({
    required String cpf,
    required String password,
    String? baseUrl,
  });

  /// Verifica se a sessão atual é válida
  Future<bool> verifySession();

  /// Realiza o logout do morador
  Future<void> logout();

  /// Retorna a sessão atual armazenada localmente
  Future<MoradorSessionEntity?> getLocalSession();

  /// Solicita recuperação de senha
  Future<void> requestPasswordRecovery(String email);
}
