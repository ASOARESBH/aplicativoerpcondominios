import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/employee_auth_provider.dart';

class EmployeeShellScreen extends ConsumerStatefulWidget {
  const EmployeeShellScreen({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<EmployeeShellScreen> createState() =>
      _EmployeeShellScreenState();
}

class _EmployeeShellScreenState extends ConsumerState<EmployeeShellScreen> {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      await ref.read(employeeAuthProvider.notifier).restoreSession();
      if (mounted) setState(() => _restoring = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeAuthProvider);
    if (_restoring || state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/employee/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final path = GoRouterState.of(context).matchedLocation;
    final index = path == '/employee/tickets'
        ? 2
        : path == '/employee/protocols'
            ? 1
            : 0;
    final tenant = state.session?['tenant'] as Map?;
    final tenantName = tenant?['nome']?.toString() ?? 'ERP Condomínios';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal do Colaborador'),
        actions: [
          Tooltip(
            message: tenantName,
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.apartment_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Sair do Portal do Colaborador',
            onPressed: () async {
              await ref.read(employeeAuthProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (selected) {
          switch (selected) {
            case 0:
              context.go('/employee');
            case 1:
              context.go('/employee/protocols');
            case 2:
              context.go('/employee/tickets');
            case 3:
              _showMoreActions(context);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Protocolos',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Chamados',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Mais',
          ),
        ],
      ),
    );
  }

  void _showMoreActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Receber mercadoria'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/employee/receive');
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text('Ler QR Code para entrega'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/employee/scan');
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Confirmar entrega'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/employee/deliver');
              },
            ),
          ],
        ),
      ),
    );
  }
}
