import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/employee_api_client.dart';
import 'auth_provider.dart';

final employeeApiProvider = Provider<EmployeeApiClient>((ref) {
  return EmployeeApiClient(ref.read(secureStorageProvider));
});

enum EmployeeAuthStatus { unauthenticated, loading, authenticated, error }

class EmployeeAuthState {
  const EmployeeAuthState({
    this.status = EmployeeAuthStatus.unauthenticated,
    this.session,
    this.availableTenants = const [],
    this.errorMessage,
  });

  final EmployeeAuthStatus status;
  final Map<String, dynamic>? session;
  final List<Map<String, dynamic>> availableTenants;
  final String? errorMessage;

  bool get isAuthenticated => status == EmployeeAuthStatus.authenticated;
  bool get isLoading => status == EmployeeAuthStatus.loading;
  bool get requiresTenantSelection => availableTenants.isNotEmpty;

  EmployeeAuthState copyWith({
    EmployeeAuthStatus? status,
    Map<String, dynamic>? session,
    List<Map<String, dynamic>>? availableTenants,
    String? errorMessage,
  }) {
    return EmployeeAuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      availableTenants: availableTenants ?? this.availableTenants,
      errorMessage: errorMessage,
    );
  }
}

class EmployeeAuthNotifier extends StateNotifier<EmployeeAuthState> {
  EmployeeAuthNotifier(this._ref) : super(const EmployeeAuthState());

  final Ref _ref;

  Future<void> restoreSession() async {
    final storage = _ref.read(secureStorageProvider);
    final localSession = await storage.getColaboradorSession();
    final token = await storage.getColaboradorToken();
    if (localSession == null || token == null || token.isEmpty) {
      state = const EmployeeAuthState();
      return;
    }

    state = const EmployeeAuthState(status: EmployeeAuthStatus.loading);
    try {
      final response = await _ref
          .read(employeeApiProvider)
          .get(AppConstants.actionSessaoColaborador);
      final data = response.data;
      if (data is Map && data['sucesso'] == true) {
        state = EmployeeAuthState(
          status: EmployeeAuthStatus.authenticated,
          session: Map<String, dynamic>.from(localSession),
        );
      } else {
        await storage.clearColaboradorSession();
        state = EmployeeAuthState(
          status: EmployeeAuthStatus.unauthenticated,
          errorMessage: _message(data),
        );
      }
    } catch (_) {
      // Uma indisponibilidade transitória não descarta automaticamente uma
      // sessão local. As operações protegidas continuam sendo validadas pelo API.
      state = EmployeeAuthState(
        status: EmployeeAuthStatus.authenticated,
        session: Map<String, dynamic>.from(localSession),
      );
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    int? tenantId,
  }) async {
    state = const EmployeeAuthState(status: EmployeeAuthStatus.loading);
    try {
      final response = await _ref.read(employeeApiProvider).login(
            email: email,
            password: password,
            tenantId: tenantId,
          );
      final data = response.data;
      if (data is! Map || data['sucesso'] != true) {
        state = EmployeeAuthState(
          status: EmployeeAuthStatus.error,
          errorMessage: _message(data),
        );
        return false;
      }

      final payload = data['dados'];
      if (payload is Map && payload['requer_selecao_tenant'] == true) {
        final rawTenants = payload['tenants'];
        final tenants = rawTenants is List
            ? rawTenants
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        state = EmployeeAuthState(
          status: EmployeeAuthStatus.unauthenticated,
          availableTenants: tenants,
        );
        developer.log(
          'Seleção de tenant requerida (${tenants.length} opções).',
          name: 'Colaborador',
        );
        return false;
      }

      if (payload is! Map || payload['token'] == null) {
        state = const EmployeeAuthState(
          status: EmployeeAuthStatus.error,
          errorMessage: 'Resposta de sessão do colaborador inválida.',
        );
        return false;
      }

      final session = Map<String, dynamic>.from(payload);
      final token = session.remove('token').toString();
      await _ref.read(secureStorageProvider).saveColaboradorSession(
            token: token,
            session: session,
          );
      developer.log(
        'Sessão autenticada e persistida.',
        name: 'Colaborador',
      );
      state = EmployeeAuthState(
        status: EmployeeAuthStatus.authenticated,
        session: session,
      );
      return true;
    } catch (error) {
      developer.log('Falha no login: ${error.runtimeType}',
          name: 'Colaborador');
      state = EmployeeAuthState(
        status: EmployeeAuthStatus.error,
        errorMessage: _message(error),
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _ref.read(employeeApiProvider).post('logout');
    } catch (_) {
      // O token local precisa ser removido mesmo se o servidor estiver offline.
    }
    await _ref.read(secureStorageProvider).clearColaboradorSession();
    developer.log('Sessão encerrada.', name: 'Colaborador');
    state = const EmployeeAuthState();
  }

  String _message(dynamic value) {
    if (value is Map && value['mensagem'] != null) {
      return value['mensagem'].toString();
    }
    final message = value.toString().replaceFirst('Exception: ', '');
    return message.isEmpty
        ? 'Não foi possível acessar o Portal do Colaborador.'
        : message;
  }
}

final employeeAuthProvider =
    StateNotifierProvider<EmployeeAuthNotifier, EmployeeAuthState>((ref) {
  return EmployeeAuthNotifier(ref);
});
