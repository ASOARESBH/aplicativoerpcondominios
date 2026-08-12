import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/employee_auth_provider.dart';

class EmployeeProtocolsScreen extends ConsumerStatefulWidget {
  const EmployeeProtocolsScreen({super.key});

  @override
  ConsumerState<EmployeeProtocolsScreen> createState() =>
      _EmployeeProtocolsScreenState();
}

class _EmployeeProtocolsScreenState
    extends ConsumerState<EmployeeProtocolsScreen> {
  List<Map<String, dynamic>> _protocols = const [];
  bool _loading = true;
  String _status = 'pendente';

  @override
  void initState() {
    super.initState();
    _loadProtocols();
  }

  Future<void> _loadProtocols() async {
    setState(() => _loading = true);
    try {
      final response = await ref.read(employeeApiProvider).get(
        AppConstants.actionProtocolosColaborador,
        queryParameters: {'status': _status},
      );
      final data = response.data;
      if (data is Map && data['sucesso'] == true && data['dados'] is List) {
        if (mounted) {
          setState(
            () => _protocols = data['dados']
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          );
        }
      } else {
        _show(_message(data), danger: true);
      }
    } catch (error) {
      developer.log('Falha ao carregar protocolos: ${error.runtimeType}',
          name: 'ColaboradorProtocolos');
      _show('Não foi possível carregar os protocolos.', danger: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/employee/receive'),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Receber'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'pendente',
                  icon: Icon(Icons.inventory_2_outlined),
                  label: Text('Pendentes'),
                ),
                ButtonSegment(
                  value: 'entregue',
                  icon: Icon(Icons.task_alt_outlined),
                  label: Text('Entregues'),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (selection) {
                setState(() => _status = selection.first);
                _loadProtocols();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadProtocols,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _protocols.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Icon(
                              _status == 'pendente'
                                  ? Icons.inventory_2_outlined
                                  : Icons.task_alt_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                _status == 'pendente'
                                    ? 'Não há mercadorias pendentes.'
                                    : 'Não há entregas registradas.',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _protocols.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _protocolCard(_protocols[index]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _protocolCard(Map<String, dynamic> protocol) {
    final delivered = protocol['status']?.toString() == 'entregue';
    final color = delivered ? AppTheme.success : AppTheme.warning;
    final title = protocol['descricao_mercadoria']?.toString() ?? 'Mercadoria';
    final resident = protocol['morador_nome']?.toString() ?? 'Morador';
    final unit = protocol['unidade_nome']?.toString() ?? 'Unidade';
    final code = protocol['codigo_nf']?.toString() ?? '';
    final date = delivered
        ? protocol['data_hora_entrega']?.toString() ?? ''
        : protocol['data_hora_recebimento']?.toString() ?? '';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: delivered
            ? null
            : () => context.go('/employee/deliver', extra: protocol),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(28),
                child: Icon(
                  delivered
                      ? Icons.check_circle_outline_rounded
                      : Icons.inventory_2_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('$resident • $unit'),
                    if (code.isNotEmpty) Text('Código: $code'),
                    Text(date, style: const TextStyle(fontSize: 12)),
                    if (delivered &&
                        (protocol['nome_recebedor_morador']?.toString() ?? '')
                            .isNotEmpty)
                      Text(
                        'Recebida por: ${protocol['nome_recebedor_morador']}',
                        style: TextStyle(color: color, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (!delivered)
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _show(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: danger ? AppTheme.danger : AppTheme.success,
      ),
    );
  }

  String _message(dynamic value) {
    if (value is Map && value['mensagem'] != null) {
      return value['mensagem'].toString();
    }
    return 'Não foi possível carregar os protocolos.';
  }
}
