import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class ProtocolsScreen extends ConsumerStatefulWidget {
  const ProtocolsScreen({super.key});
  @override
  ConsumerState<ProtocolsScreen> createState() => _ProtocolsScreenState();
}

class _ProtocolsScreenState extends ConsumerState<ProtocolsScreen> {
  List<Map<String, dynamic>> _protocols = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final statusParam = _filter.isNotEmpty ? '?status=$_filter' : '';
      final response = await dioClient.dio.get('${AppConstants.endpointProtocols}$statusParam');
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        setState(() => _protocols = List<Map<String, dynamic>>.from(data['dados'] ?? []));
      }
    } catch (e) { debugPrint('[ProtocolsScreen] Error: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterBtn('', 'Todos', Icons.list),
              const SizedBox(width: 8),
              _buildFilterBtn('pendente', 'Pendentes', Icons.access_time),
              const SizedBox(width: 8),
              _buildFilterBtn('entregue', 'Entregues', Icons.check_circle),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _protocols.isEmpty
                    ? const EmptyState(icon: Icons.inventory_2, message: 'Nenhum protocolo encontrado.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _protocols.length,
                        itemBuilder: (context, index) {
                          final p = _protocols[index];
                          final isPending = p['status']?.toString() == 'pendente';
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: isPending ? AppTheme.warning.withAlpha(26) : AppTheme.success.withAlpha(26),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(isPending ? Icons.access_time : Icons.check_circle, color: isPending ? AppTheme.warning : AppTheme.success),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p['descricao']?.toString() ?? p['tipo']?.toString() ?? 'Encomenda', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(p['remetente']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        Text(p['data_recebimento']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPending ? AppTheme.warning.withAlpha(26) : AppTheme.success.withAlpha(26),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(isPending ? 'Pendente' : 'Entregue', style: TextStyle(color: isPending ? AppTheme.warning : AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBtn(String value, String label, IconData icon) {
    final isSelected = value == _filter;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _filter = value); _loadData(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.primary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

void debugPrint(String message) { print(message); }
