import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});
  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.get(AppConstants.endpointPortal);
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        final dados = data['dados'];
        if (dados is Map && dados['veiculos'] != null) {
          setState(() => _vehicles = List<Map<String, dynamic>>.from(dados['veiculos']));
        } else if (dados is List) {
          setState(() => _vehicles = List<Map<String, dynamic>>.from(dados));
        }
      }
    } catch (e) { debugPrint('[VehiclesScreen] Error: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? const EmptyState(icon: Icons.directions_car, message: 'Nenhum veículo cadastrado.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vehicles.length,
                  itemBuilder: (context, index) {
                    final v = _vehicles[index];
                    final isAtivo = v['ativo'] == 1 || v['ativo'] == true;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: isAtivo ? AppTheme.primaryLight : Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.directions_car, color: isAtivo ? AppTheme.primary : Colors.grey),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[900],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(v['placa']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5)),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!isAtivo)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: AppTheme.danger.withAlpha(26), borderRadius: BorderRadius.circular(10)),
                                          child: const Text('Inativo', style: TextStyle(color: AppTheme.danger, fontSize: 11)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('${v['modelo'] ?? ''} ${v['cor'] ?? ''}'.trim(), style: const TextStyle(fontSize: 13)),
                                  if (v['dependente_nome'] != null)
                                    Text('Dependente: ${v['dependente_nome']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  if (v['tag'] != null && v['tag'].toString().isNotEmpty)
                                    Text('TAG: ${v['tag']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

void debugPrint(String message) { print(message); }
