import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/visitors/visitors_screen.dart';
import '../screens/access/access_screen.dart';
import '../screens/dependents/dependents_screen.dart';
import '../screens/protocols/protocols_screen.dart';
import '../screens/water_meter/water_meter_screen.dart';
import '../screens/vehicles/vehicles_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/projects/projects_screen.dart';
import '../screens/tickets/tickets_screen.dart';
import '../screens/marketplace/marketplace_screen.dart';
import '../screens/notifications/notifications_screen.dart';

/// Rotas nomeadas do aplicativo
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String visitors = '/visitors';
  static const String access = '/access';
  static const String dependents = '/dependents';
  static const String protocols = '/protocols';
  static const String waterMeter = '/water-meter';
  static const String vehicles = '/vehicles';
  static const String documents = '/documents';
  static const String projects = '/projects';
  static const String tickets = '/tickets';
  static const String marketplace = '/marketplace';
  static const String notifications = '/notifications';
}

/// Configuração do roteador GoRouter com redirect automático
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final currentPath = state.matchedLocation;
      final isPublicPage = currentPath == AppRoutes.login ||
          currentPath == AppRoutes.forgotPassword ||
          currentPath == AppRoutes.splash;

      // Nunca redirecionar enquanto está carregando
      if (isLoading) return null;

      // Se não autenticado e tentando acessar página protegida → login
      if (!isAuthenticated && !isPublicPage) return AppRoutes.login;

      // Se autenticado e na tela de login → home
      if (isAuthenticated && currentPath == AppRoutes.login) {
        return AppRoutes.profile;
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
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const ProfileScreen(),
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
              onPressed: () => context.go(AppRoutes.profile),
              child: const Text('Ir para Início'),
            ),
          ],
        ),
      ),
    ),
  );
});
