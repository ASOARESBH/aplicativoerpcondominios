import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/employee_auth_provider.dart';

class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends ConsumerState<EmployeeDashboardScreen> {
  Map<String, dynamic> _metrics = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final response = await ref
          .read(employeeApiProvider)
          .get(AppConstants.actionDashboardColaborador);
      final data = response.data;
      if (data is Map && data['sucesso'] == true && data['dados'] is Map) {
        if (mounted) {
          setState(() => _metrics = Map<String, dynamic>.from(data['dados']));
        }
      }
    } catch (error) {
      developer.log('Falha ao carregar painel: ${error.runtimeType}',
          name: 'Colaborador');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(employeeAuthProvider).session;
    final user = session?['usuario'] as Map?;
    final tenant = session?['tenant'] as Map?;
    final name = user?['nome']?.toString() ?? 'Colaborador';
    final function = user?['funcao']?.toString() ?? 'Operador';
    final tenantName = tenant?['nome']?.toString() ?? 'Condomínio';

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$function • $tenantName',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _metricsRow(),
          const SizedBox(height: 24),
          Text(
            'Operações',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.18,
            children: [
              _module(
                context,
                icon: Icons.support_agent_outlined,
                title: 'Abrir chamado',
                subtitle: 'Solicitar atendimento',
                route: '/employee/tickets/new',
              ),
              _module(
                context,
                icon: Icons.inventory_2_outlined,
                title: 'Receber protocolo',
                subtitle: 'Cadastrar mercadoria',
                route: '/employee/receive',
              ),
              _module(
                context,
                icon: Icons.qr_code_scanner_rounded,
                title: 'Ler QR Code',
                subtitle: 'Ler etiqueta ou produto',
                route: '/employee/scan',
              ),
              _module(
                context,
                icon: Icons.local_shipping_outlined,
                title: 'Entregar',
                subtitle: 'Validar recebedor',
                route: '/employee/deliver',
              ),
              _module(
                context,
                icon: Icons.history_rounded,
                title: 'Protocolos',
                subtitle: 'Pendentes e histórico',
                route: '/employee/protocols',
              ),
              _module(
                context,
                icon: Icons.water_drop_outlined,
                title: 'Leitura de água',
                subtitle: 'Lançar hidrômetro',
                route: '/employee/water-meter',
              ),
              _module(
                context,
                icon: Icons.list_alt_outlined,
                title: 'Meus chamados',
                subtitle: 'Acompanhar solicitações',
                route: '/employee/tickets',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricsRow() {
    final cards = [
      (
        'Pendentes',
        _metrics['protocolos_pendentes'],
        Icons.inventory_2_outlined
      ),
      ('Chamados', _metrics['chamados_abertos'], Icons.support_agent_outlined),
      ('Entregas hoje', _metrics['entregas_hoje'], Icons.task_alt_outlined),
    ];
    return Row(
      children: cards
          .map(
            (metric) => Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Icon(metric.$3, color: AppTheme.primary),
                      const SizedBox(height: 6),
                      Text(
                        _loading ? '—' : '${metric.$2 ?? 0}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        metric.$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _module(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go(route),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.primary, size: 28),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
