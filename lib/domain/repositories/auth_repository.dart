import '../entities/morador_entity.dart';

/// Interface do repositório de autenticação.
/// URL base FIXA — multi-tenant por token Bearer, não por URL.
abstract class AuthRepository {
  /// Realiza o login do morador com CPF e senha.
  /// O tenant é identificado automaticamente pelo servidor via token.
  Future<MoradorSessionEntity> login({
    required String cpf,
    required String password,
  });

  /// Verifica se a sessão atual (token) ainda é válida no servidor.
  Future<bool> verifySession();

  /// Realiza o logout invalidando o token no servidor e limpando dados locais.
  Future<void> logout();

  /// Retorna a sessão salva localmente (sem chamada de rede).
  Future<MoradorSessionEntity?> getLocalSession();

  /// Solicita recuperação de senha por e-mail.
  Future<void> requestPasswordRecovery(String email);
}
