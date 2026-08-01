import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/security/secure_storage_service.dart';
import '../../data/datasources/remote/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/morador_entity.dart';
import '../../domain/repositories/auth_repository.dart';

// ─── Infrastructure Providers ─────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final dioClientProvider = Provider<DioClient>((ref) {
  final secureStorage = ref.read(secureStorageProvider);
  return DioClient(secureStorage);
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dioClient = ref.read(dioClientProvider);
  return AuthRemoteDataSource(dioClient);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.read(authRemoteDataSourceProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return AuthRepositoryImpl(remoteDataSource, secureStorage);
});

// ─── Auth State ───────────────────────────────────────────────────────────────

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final MoradorSessionEntity? session;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    MoradorSessionEntity? session,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository)
      : super(const AuthState(status: AuthStatus.unauthenticated));

  /// Verifica sessão local ao iniciar o app
  Future<void> checkSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final localSession = await _repository.getLocalSession();
      if (localSession == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      final isValid = await _repository.verifySession();
      if (isValid) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          session: localSession,
        );
      } else {
        await _repository.logout();
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Realiza o login
  Future<void> login({
    required String cpf,
    required String password,
    String? baseUrl,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final session = await _repository.login(
        cpf: cpf,
        password: password,
        baseUrl: baseUrl,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Realiza o logout
  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return AuthNotifier(repository);
});
