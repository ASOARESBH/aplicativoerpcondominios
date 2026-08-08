import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;
  String _statusFilter = '';
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      final statusParam = _statusFilter.isNotEmpty ? '&status=$_statusFilter' : '';
      final results = await Future.wait([
        dioClient.dio.get(AppConstants.endpointOS, queryParameters: {'action': 'listar_assuntos'}),
        dioClient.dio.get(AppConstants.endpointOS, queryParameters: {'action': 'listar', 'pagina': _page, if (statusParam.isNotEmpty) 'status': statusParam.replaceAll('&status=', '')}),
      ]);
      final subjectsData = results[0].data as Map<String, dynamic>;
      final ticketsData = results[1].data as Map<String, dynamic>;
      if (subjectsData['sucesso'] == true) {
        setState(() => _subjects = List<Map<String, dynamic>>.from(subjectsData['dados'] ?? []));
      }
      if (ticketsData['sucesso'] == true) {
        final dados = ticketsData['dados'] as Map<String, dynamic>?;
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(dados?['lista'] ?? []);
          _totalPages = (dados?['paginas'] as int?) ?? 1;
        });
      }
    } catch (e) {
      debugPrint('[TicketsScreen] Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'aberto': return AppTheme.primary;
      case 'andamento': return AppTheme.warning;
      case 'finalizado': return AppTheme.success;
      case 'cancelado': return AppTheme.danger;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    const labels = {'aberto': 'Aberto', 'andamento': 'Em Andamento', 'finalizado': 'Finalizado', 'cancelado': 'Cancelado'};
    return labels[status] ?? status;
  }

  String _priorityLabel(String priority) {
    const labels = {'baixa': 'Baixa', 'media': 'Média', 'alta': 'Alta', 'urgente': 'Urgente'};
    return labels[priority] ?? priority;
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'baixa': return Colors.grey;
      case 'media': return AppTheme.warning;
      case 'alta': return Colors.orange;
      case 'urgente': return AppTheme.danger;
      default: return Colors.grey;
    }
  }

  void _openNewTicketModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NewTicketSheet(subjects: _subjects, dioClient: ref.read(dioClientProvider), onSuccess: _loadData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewTicketModal,
        icon: const Icon(Icons.add),
        label: const Text('Novo Chamado'),
        backgroundColor: AppTheme.primary,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['', 'aberto', 'andamento', 'finalizado'].map((v) {
                    final labels = {'': 'Todos', 'aberto': 'Abertos', 'andamento': 'Em Andamento', 'finalizado': 'Finalizados'};
                    final isSelected = v == _statusFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () { setState(() { _statusFilter = v; _page = 1; }); _loadData(); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(labels[v]!, style: TextStyle(color: isSelected ? Colors.white : AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tickets.isEmpty
                      ? EmptyState(icon: Icons.support_agent, message: 'Nenhum chamado encontrado.', actionLabel: 'Abrir Chamado', onAction: _openNewTicketModal)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tickets.length,
                          itemBuilder: (context, index) {
                            final t = _tickets[index];
                            final status = t['status']?.toString() ?? '';
                            final priority = t['prioridade']?.toString() ?? '';
                            final data = t['data_abertura']?.toString() ?? '';
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _openTicketDetail(t),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(t['titulo']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                          Text(t['numero']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _Badge(label: _statusLabel(status), color: _statusColor(status)),
                                          _Badge(label: _priorityLabel(priority), color: _priorityColor(priority)),
                                          if (t['assunto_nome'] != null) _Badge(label: t['assunto_nome'].toString(), color: Colors.grey),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(data.length >= 16 ? data.substring(0, 16) : data, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const Spacer(),
                                          if ((t['total_interacoes'] as int? ?? 0) > 0) ...[
                                            const Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text('${t['total_interacoes']} msgs', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTicketDetail(Map<String, dynamic> ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TicketDetailSheet(ticket: ticket, dioClient: ref.read(dioClientProvider)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(77))),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _NewTicketSheet extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;
  final dynamic dioClient;
  final VoidCallback onSuccess;
  const _NewTicketSheet({required this.subjects, required this.dioClient, required this.onSuccess});
  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  int? _selectedSubjectId;
  bool _submitting = false;

  @override
  void dispose() { _tituloController.dispose(); _descricaoController.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.dioClient.initBaseUrl();
      final response = await widget.dioClient.dio.post(
        '${AppConstants.endpointOS}?action=abrir',
        data: {'titulo': _tituloController.text, 'assunto_id': _selectedSubjectId, 'descricao': _descricaoController.text},
      );
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['mensagem']?.toString() ?? ''), backgroundColor: data['sucesso'] == true ? AppTheme.success : AppTheme.danger));
        if (data['sucesso'] == true) widget.onSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [const Text('Novo Chamado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
              const SizedBox(height: 16),
              TextFormField(controller: _tituloController, decoration: const InputDecoration(labelText: 'Título *'), validator: (v) => Validators.validateRequired(v, 'Título')),
              const SizedBox(height: 12),
              if (widget.subjects.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: _selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Assunto'),
                  items: widget.subjects.map((s) => DropdownMenuItem<int>(value: int.tryParse(s['id'].toString()), child: Text('${s['nome']}${s['departamento'] != null ? ' — ${s['departamento']}' : ''}'))).toList(),
                  onChanged: (v) => setState(() => _selectedSubjectId = v),
                ),
              const SizedBox(height: 12),
              TextFormField(controller: _descricaoController, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(labelText: 'Descrição *'), validator: (v) => Validators.validateRequired(v, 'Descrição')),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                label: const Text('Enviar Chamado'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketDetailSheet extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final dynamic dioClient;
  const _TicketDetailSheet({required this.ticket, required this.dioClient});
  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet> {
  List<Map<String, dynamic>> _interactions = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadDetail(); }

  Future<void> _loadDetail() async {
    try {
      await widget.dioClient.initBaseUrl();
      final id = widget.ticket['id'];
      final response = await widget.dioClient.dio.get(AppConstants.endpointOS, queryParameters: {'action': 'detalhe', 'id': id});
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        final dados = data['dados'] as Map<String, dynamic>?;
        setState(() => _interactions = List<Map<String, dynamic>>.from(dados?['timeline'] ?? dados?['interacoes'] ?? []));
      }
    } catch (e) { debugPrint('[TicketDetail] Error: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: Text(t['titulo']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
            Text('Chamado ${t['numero']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            const Divider(),
            const Text('Histórico', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _interactions.isEmpty
                      ? const EmptyState(icon: Icons.chat_bubble_outline, message: 'Nenhuma interação registrada.')
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _interactions.length,
                          itemBuilder: (context, index) {
                            final i = _interactions[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(i['autor_nome']?.toString() ?? 'Sistema', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Spacer(),
                                    Text(i['data_interacao']?.toString().substring(0, 16) ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(i['mensagem']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
