import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';

/// Tela principal com Bottom Navigation Bar e Drawer para módulos secundários
class HomeScreen extends ConsumerStatefulWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  // Itens do Bottom Navigation (módulos principais)
  static const _navItems = [
    _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Início',
        route: '/home'),
    _NavItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'Visitantes',
        route: '/home/visitors'),
    _NavItem(
        icon: Icons.build_outlined,
        activeIcon: Icons.build,
        label: 'Chamados',
        route: '/home/tickets'),
    _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Perfil',
        route: '/home/profile'),
    _NavItem(
        icon: Icons.menu,
        activeIcon: Icons.menu_open,
        label: 'Mais',
        route: null),
  ];

  // Módulos do Drawer (módulos secundários)
  static const _drawerItems = [
    _DrawerItem(
        icon: Icons.family_restroom,
        label: 'Dependentes',
        route: '/home/dependents'),
    _DrawerItem(
        icon: Icons.inventory_2_outlined,
        label: 'Protocolos',
        route: '/home/protocols'),
    _DrawerItem(
        icon: Icons.directions_car_outlined,
        label: 'Veículos',
        route: '/home/vehicles'),
    _DrawerItem(
        icon: Icons.folder_outlined,
        label: 'Documentos',
        route: '/home/documents'),
    _DrawerItem(
        icon: Icons.construction_outlined,
        label: 'Projetos',
        route: '/home/projects'),
    _DrawerItem(
        icon: Icons.shield_outlined,
        label: 'Controle de Acesso',
        route: '/home/access-control'),
    _DrawerItem(
        icon: Icons.support_agent_outlined,
        label: 'Chamados',
        route: '/home/tickets'),
    _DrawerItem(
        icon: Icons.store_outlined,
        label: 'Marketplace',
        route: '/home/marketplace'),
    _DrawerItem(
        icon: Icons.notifications_outlined,
        label: 'Notificações',
        route: '/home/notifications'),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final session = authState.session;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.apartment, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  AppConstants.appName,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (session?.unidade != null)
                  Text(
                    'Unidade ${session!.unidade}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go('/home/notifications'),
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              radius: 16,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sair'),
                    content: const Text('Deseja realmente sair do portal?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                        ),
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session?.nome ?? 'Morador',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      session?.email ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppTheme.danger),
                    SizedBox(width: 8),
                    Text('Sair', style: TextStyle(color: AppTheme.danger)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context, session),
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 4) {
            // O contexto do State fica acima do Scaffold. Usar a chave evita
            // Scaffold.of(context) em contexto inválido e mantém o app aberto.
            debugPrint('[Home] Abrindo menu Mais.');
            _scaffoldKey.currentState?.openDrawer();
            return;
          }
          setState(() => _currentIndex = index);
          final route = _navItems[index].route;
          if (route != null) context.go(route);
        },
        items: _navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, session) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
              ),
            ),
            accountName: Text(session?.nome ?? 'Morador'),
            accountEmail: Text(
              session?.unidade != null ? 'Unidade ${session!.unidade}' : '',
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: const Icon(Icons.person, color: Colors.white, size: 36),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _drawerItems
                  .map((item) => ListTile(
                        leading: Icon(item.icon, color: AppTheme.primary),
                        title: Text(item.label),
                        onTap: () {
                          Navigator.pop(context);
                          context.go(item.route);
                        },
                      ))
                  .toList(),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.danger),
            title: const Text(
              'Sair',
              style: TextStyle(color: AppTheme.danger),
            ),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? route;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final String route;
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
