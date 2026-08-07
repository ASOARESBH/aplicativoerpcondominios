import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../models/morador_model.dart';

/// Datasource remoto para autenticação do Portal do Morador.
///
/// URL base FIXA: [AppConstants.baseUrl] = https://app.erpcondominios.com.br
/// Multi-tenant por token Bearer — não por URL customizada.
class AuthRemoteDataSource {
  final DioClient _dioClient;

  AuthRemoteDataSource(this._dioClient);

  /// Realiza o login do morador.
  ///
  /// Envia CPF (somente dígitos) + senha para a API.
  /// O backend retorna: {sucesso, mensagem, dados: {token, morador_id, morador_nome, unidade}}
  Future<LoginResponseModel> login({
    required String cpf,
    required String password,
  }) async {
    try {
      // Remove qualquer pontuação do CPF antes de enviar
      final cpfLimpo = cpf.replaceAll(RegExp(r'[^\d]'), '');

      final response = await _dioClient.dio.post(
        AppConstants.endpointLogin,
        queryParameters: {'action': AppConstants.actionLogin},
        data: {
          'cpf':   cpfLimpo,
          'senha': password,
        },
      );

      final body = response.data as Map<String, dynamic>;

      // A API retorna sucesso:false com status 200 para erros de negócio
      if (body['sucesso'] != true) {
        throw ValidationException(
          body['mensagem']?.toString() ?? 'Credenciais inválidas.',
        );
      }

      return LoginResponseModel.fromJson(body);
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      throw NetworkException(e.message ?? 'Erro de conexão com o servidor.');
    }
  }

  /// Verifica se o token atual ainda é válido.
  /// Retorna true se a sessão estiver ativa.
  Future<bool> verifySession() async {
    try {
      final response = await _dioClient.dio.get(
        AppConstants.endpointVerifySession,
        queryParameters: {'action': AppConstants.actionVerifySession},
      );
      final data = response.data as Map<String, dynamic>;
      return data['sucesso'] == true;
    } on DioException catch (e) {
      // 401 = sessão expirada (comportamento esperado)
      if (e.response?.statusCode == 401) return false;
      if (e.error is AppException) throw e.error as AppException;
      throw NetworkException(e.message ?? 'Erro ao verificar sessão.');
    }
  }

  /// Realiza o logout invalidando o token no servidor.
  Future<void> logout() async {
    try {
      await _dioClient.dio.post(AppConstants.endpointLogout);
    } catch (_) {
      // Ignora erros no logout — a sessão local é limpa de qualquer forma
    }
  }

  /// Solicita recuperação de senha por e-mail.
  Future<void> requestPasswordRecovery(String email) async {
    try {
      final response = await _dioClient.dio.post(
        AppConstants.endpointPasswordRecovery,
        data: {'email': email},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] != true) {
        throw ValidationException(
          data['mensagem']?.toString() ?? 'Erro ao solicitar recuperação.',
        );
      }
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      throw NetworkException(e.message ?? 'Erro de conexão.');
    }
  }
}
