/// Exceções customizadas do aplicativo ERP Condomínios
class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => 'AppException: $message (status: $statusCode)';
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Sessão expirada. Faça login novamente.'])
      : super(statusCode: 401);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Erro de conexão. Verifique sua internet.']);
}

class ServerException extends AppException {
  const ServerException([super.message = 'Erro no servidor. Tente novamente.'])
      : super(statusCode: 500);
}

class ValidationException extends AppException {
  const ValidationException(super.message) : super(statusCode: 422);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Recurso não encontrado.'])
      : super(statusCode: 404);
}

class TimeoutException extends AppException {
  const TimeoutException([super.message = 'Tempo limite excedido. Tente novamente.']);
}
