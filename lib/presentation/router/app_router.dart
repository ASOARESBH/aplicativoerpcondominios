import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/access/access_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dependents/dependents_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/employee/employee_dashboard_screen.dart';
import '../screens/employee/employee_delivery_screen.dart';
import '../screens/employee/employee_login_screen.dart';
import '../screens/employee/employee_shell_screen.dart';
import '../screens/employee/employee_protocols_screen.dart';
import '../screens/employee/employee_receive_protocol_screen.dart';
import '../screens/employee/employee_qr_scanner_screen.dart';
import '../screens/employee/employee_tickets_screen.dart';
import '../screens/employee/employee_water_meter_read_screen.dart';
import '../screens/employee/employee_water_meter_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/marketplace/marketplace_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/projects/projects_screen.dart';
import '../screens/protocols/protocols_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/tickets/tickets_screen.dart';
import '../screens/vehicles/vehicles_screen.dart';
import '../screens/visitors/visitors_screen.dart';
import '../screens/water_meter/water_meter_screen.dart';

/// Rotas nomeadas do aplicativo.
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String employeeLogin = '/employee/login';
  static const String employeeHome = '/employee';
  static const String employeeWaterMeter = '/employee/water-meter';

  static const String home = '/home';
  static const String profile = '/home/profile';
  static const String visitors = '/home/visitors';
  static const String access = '/home/access';
  static const String dependents = '/home/dependents';
  static const String protocols = '/home/protocols';
  static const String waterMeter = '/home/water-meter';
  static const String vehicles = '/home/vehicles';
  static const String documents = '/home/documents';
  static const String projects = '/home/projects';
  static const String tickets = '/home/tickets';
  static const String marketplace = '/home/marketplace';
  static const String notifications = '/home/notifications';
}

/// Atualiza o redirect do GoRouter sem recriar o roteador nem perder a árvore
/// de navegação quando o estado de autenticação muda.
class _AuthRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _authRouterRefreshProvider = Provider<_AuthRouterRefresh>((ref) {
  final refresh = _AuthRouterRefresh();
  ref.listen<AuthState>(authProvider, (_, next) {
    developer.log(
      'auth=${next.status.name}; solicitando atualização de rota',
      name: 'Router',
    );
    refresh.refresh();
  });
  ref.onDispose(refresh.dispose);
  return refresh;
});

/// O roteador é criado uma única vez. A versão anterior observava diretamente
/// [authProvider] e recriava todo o GoRouter após o login, concorrendo com a
/// navegação da tela de autenticação e podendo deixar a UI sem responder.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_authRouterRefreshProvider);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final currentPath = state.matchedLocation;
      final isPublicPage = currentPath == AppRoutes.login ||
          currentPath == AppRoutes.forgotPassword ||
          currentPath == AppRoutes.splash;
      final isEmployeeRoute = currentPath.startsWith('/employee');

      // O Portal do Colaborador possui sessão Bearer própria e não pode ser
      // redirecionado pelo estado da sessão do morador.
      if (isEmployeeRoute) return null;

      // A SplashScreen decide a restauração de sessão. Não navegar durante a
      // fase de loading evita loops e preserva uma tela responsiva.
      if (authState.isLoading || currentPath == AppRoutes.splash) return null;

      if (!authState.isAuthenticated && !isPublicPage) {
        return AppRoutes.login;
      }

      if (authState.isAuthenticated &&
          (currentPath == AppRoutes.login ||
              currentPath == AppRoutes.forgotPassword)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.employeeLogin,
        name: 'employee-login',
        builder: (context, state) => const EmployeeLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => EmployeeShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.employeeHome,
            name: 'employee-home',
            builder: (context, state) => const EmployeeDashboardScreen(),
          ),
          GoRoute(
            path: '/employee/tickets',
            name: 'employee-tickets',
            builder: (context, state) => const EmployeeTicketsScreen(),
          ),
          GoRoute(
            path: '/employee/tickets/new',
            name: 'employee-ticket-new',
            builder: (context, state) =>
                const EmployeeTicketsScreen(openForm: true),
          ),
          GoRoute(
            path: '/employee/protocols',
            name: 'employee-protocols',
            builder: (context, state) => const EmployeeProtocolsScreen(),
          ),
          GoRoute(
            path: '/employee/receive',
            name: 'employee-receive',
            builder: (context, state) => const EmployeeReceiveProtocolScreen(),
          ),
          GoRoute(
            path: '/employee/scan',
            name: 'employee-scan',
            builder: (context, state) => const EmployeeQrScannerScreen(),
          ),
          GoRoute(
            path: AppRoutes.employeeWaterMeter,
            name: 'employee-water-meter',
            builder: (context, state) => const EmployeeWaterMeterScreen(),
          ),
          GoRoute(
            path: '/employee/water-meter/read',
            name: 'employee-water-meter-read',
            builder: (context, state) {
              final selection = state.extra;
              if (selection is! Map) {
                return const Scaffold(
                  body: Center(
                      child: Text(
                          'Selecione um hidrômetro antes de lançar a leitura.')),
                );
              }
              return EmployeeWaterMeterReadScreen(
                selection: Map<String, dynamic>.from(selection),
              );
            },
          ),
          GoRoute(
            path: '/employee/deliver',
            name: 'employee-deliver',
            builder: (context, state) => EmployeeDeliveryScreen(
              initialProtocol: state.extra is Map
                  ? Map<String, dynamic>.from(state.extra as Map)
                  : null,
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.visitors,
            name: 'visitors',
            builder: (context, state) => const VisitorsScreen(),
          ),
          GoRoute(
            path: AppRoutes.access,
            name: 'access',
            builder: (context, state) => const AccessScreen(),
          ),
          GoRoute(
            path: AppRoutes.dependents,
            name: 'dependents',
            builder: (context, state) => const DependentsScreen(),
          ),
          GoRoute(
            path: AppRoutes.protocols,
            name: 'protocols',
            builder: (context, state) => const ProtocolsScreen(),
          ),
          GoRoute(
            path: AppRoutes.waterMeter,
            name: 'water-meter',
            builder: (context, state) => const WaterMeterScreen(),
          ),
          GoRoute(
            path: AppRoutes.vehicles,
            name: 'vehicles',
            builder: (context, state) => const VehiclesScreen(),
          ),
          GoRoute(
            path: AppRoutes.documents,
            name: 'documents',
            builder: (context, state) => const DocumentsScreen(),
          ),
          GoRoute(
            path: AppRoutes.projects,
            name: 'projects',
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: AppRoutes.tickets,
            name: 'tickets',
            builder: (context, state) => const TicketsScreen(),
          ),
          GoRoute(
            path: AppRoutes.marketplace,
            name: 'marketplace',
            builder: (context, state) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Página não encontrada: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Ir para Início'),
            ),
          ],
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
