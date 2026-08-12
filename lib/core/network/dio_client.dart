import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../errors/app_exceptions.dart';
import '../security/secure_storage_service.dart';

/// Cliente HTTP centralizado do app ERP Condomínios.
///
/// MULTI-TENANT: A URL base é FIXA em [AppConstants.baseUrl].
/// Todos os condomínios usam https://app.erpcondominios.com.br/
/// O tenant é identificado pelo token Bearer gerado no login.
/// NÃO há troca dinâmica de URL — removido updateBaseUrl/initBaseUrl.
class DioClient {
  late final Dio _dio;
  final SecureStorageService _secureStorage;

  DioClient(this._secureStorage) {
    _dio = Dio(
      BaseOptions(
        // URL FIXA — multi-tenant por token, não por URL
        baseUrl: AppConstants.baseUrl,
        connectTimeout:
            const Duration(milliseconds: AppConstants.connectTimeoutMs),
        receiveTimeout:
            const Duration(milliseconds: AppConstants.receiveTimeoutMs),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Aceita qualquer status < 500 para tratar erros de negócio no app
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(_secureStorage),
      _ErrorInterceptor(),
      // Nunca registrar corpos de requisição/resposta: podem conter senha,
      // token de morador ou token do colaborador.
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (obj) => _log('[DioClient] $obj'),
      ),
    ]);
  }

  Dio get dio => _dio;

  /// Limpa o token de autenticação do header (usado no logout).
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

/// Interceptor de autenticação: injeta o Bearer Token em todas as requisições
class _AuthInterceptor extends Interceptor {
  final SecureStorageService _secureStorage;

  _AuthInterceptor(this._secureStorage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Não injeta token nas rotas públicas (login, recuperação de senha)
    final isPublicRoute = options.uri.toString().contains('action=login') ||
        options.uri.toString().contains('api_recuperar_senha');

    if (!isPublicRoute) {
      final token = await _secureStorage.getAuthToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

/// Interceptor de erros: converte erros HTTP em exceções tipadas
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppException exception;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        exception = const TimeoutException();
        break;
      case DioExceptionType.connectionError:
        exception = const NetworkException();
        break;
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        if (statusCode == 401) {
          exception = const UnauthorizedException();
        } else if (statusCode == 404) {
          exception = const NotFoundException();
        } else if (statusCode != null && statusCode >= 500) {
          exception = const ServerException();
        } else {
          final message = _extractMessage(err.response?.data);
          exception = AppException(message, statusCode: statusCode);
        }
        break;
      default:
        exception = AppException(err.message ?? 'Erro desconhecido.');
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        message: exception.message,
        type: err.type,
        response: err.response,
      ),
    );
  }

  String _extractMessage(dynamic data) {
    if (data is Map && data['mensagem'] != null) {
      return data['mensagem'].toString();
    }
    return 'Erro ao processar a requisição.';
  }
}

void _log(String message) {
  // ignore: avoid_print
  print(message);
}
