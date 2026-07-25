import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});
  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  Map<String, dynamic>? _selectedProject;
  List<Map<String, dynamic>> _timeline = [];
  bool _loadingDetail = false;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final response = await dioClient.dio.get('${AppConstants.endpointProjects}?acao=listar');
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        final dados = data['dados'];
        if (dados is Map && dados['projetos'] != null) setState(() => _projects = List<Map<String, dynamic>>.from(dados['projetos']));
        else if (dados is List) setState(() => _projects = List<Map<String, dynamic>>.from(dados));
      }
    } catch (e) { debugPrint('[ProjectsScreen] Error: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadDetail(int id) async {
    setState(() { _loadingDetail = true; _timeline = []; });
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final response = await dioClient.dio.get('${AppConstants.endpointProjects}?acao=detalhe&id=$id');
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        final dados = data['dados'] as Map<String, dynamic>?;
        setState(() {
          _selectedProject = dados?['projeto'] as Map<String, dynamic>?;
          _timeline = List<Map<String, dynamic>>.from(dados?['timeline'] ?? []);
        });
      }
    } catch (e) { debugPrint('[ProjectsScreen] Detail error: $e'); }
    finally { if (mounted) setState(() => _loadingDetail = false); }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'planejamento': return Colors.grey;
      case 'execucao': return AppTheme.primary;
      case 'finalizado': return AppTheme.success;
      case 'cancelado': return AppTheme.danger;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    const labels = {'planejamento': 'Planejamento', 'execucao': 'Em Execução', 'finalizado': 'Finalizado', 'cancelado': 'Cancelado'};
    return labels[status] ?? status ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedProject != null) return _buildDetail();
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? const EmptyState(icon: Icons.construction, message: 'Nenhum projeto encontrado.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final p = _projects[index];
                    final pct = int.tryParse(p['projeto_percentual']?.toString() ?? '0') ?? 0;
                    final status = p['projeto_status']?.toString();
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () { _loadDetail(int.tryParse(p['id'].toString()) ?? 0); },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Container(
                                height: 120,
                                color: AppTheme.primaryLight,
                                child: const Center(child: Icon(Icons.construction, size: 48, color: AppTheme.primary)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(p['projeto_nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: _statusColor(status).withAlpha(26), borderRadius: BorderRadius.circular(10)),
                                        child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: pct / 100,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: AlwaysStoppedAnimation<Color>(pct >= 80 ? AppTheme.success : pct >= 40 ? AppTheme.primary : Colors.orange),
                                            minHeight: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (p['ultima_atualizacao'] != null)
                                    Row(children: [
                                      const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('Atualizado: ${p['ultima_atualizacao']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ]),
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

  Widget _buildDetail() {
    final p = _selectedProject!;
    final pct = int.tryParse(p['projeto_percentual']?.toString() ?? '0') ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(p['projeto_nome']?.toString() ?? 'Projeto'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() { _selectedProject = null; _timeline = []; })),
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(p['projeto_nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                              Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(pct >= 80 ? AppTheme.success : pct >= 40 ? AppTheme.primary : Colors.orange),
                              minHeight: 12,
                            ),
                          ),
                          if (p['projeto_descricao'] != null) ...[
                            const SizedBox(height: 12),
                            Text(p['projeto_descricao'].toString(), style: const TextStyle(color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Linha do Tempo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          if (_timeline.isEmpty)
                            const EmptyState(icon: Icons.timeline, message: 'Nenhuma atualização pública.')
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _timeline.length,
                              itemBuilder: (context, index) {
                                final t = _timeline[index];
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          width: 24, height: 24,
                                          decoration: BoxDecoration(
                                            color: index == _timeline.length - 1 ? AppTheme.primary : AppTheme.success,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(index == _timeline.length - 1 ? Icons.radio_button_checked : Icons.check, size: 14, color: Colors.white),
                                        ),
                                        if (index < _timeline.length - 1)
                                          Container(width: 2, height: 40, color: Colors.grey[300]),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(t['etapa_nome']?.toString() ?? 'Atualização', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            if (t['mensagem'] != null) Text(t['mensagem'].toString(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                            if (t['data'] != null) Text(t['data'].toString(), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

void debugPrint(String message) { print(message); }
