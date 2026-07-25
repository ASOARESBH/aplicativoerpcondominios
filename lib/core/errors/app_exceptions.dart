/// Exceções customizadas do aplicativo ERP Condomínios
class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => 'AppException: $message (status: $statusCode)';
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Sessão expirada. Faça login novamente.'])
      : super(message, statusCode: 401);
}

class NetworkException extends AppException {
  const NetworkException([String message = 'Erro de conexão. Verifique sua internet.'])
      : super(message);
}

class ServerException extends AppException {
  const ServerException([String message = 'Erro no servidor. Tente novamente.'])
      : super(message, statusCode: 500);
}

class ValidationException extends AppException {
  const ValidationException(String message) : super(message, statusCode: 422);
}

class NotFoundException extends AppException {
  const NotFoundException([String message = 'Recurso não encontrado.'])
      : super(message, statusCode: 404);
}

class TimeoutException extends AppException {
  const TimeoutException([String message = 'Tempo limite excedido. Tente novamente.'])
      : super(message);
}
