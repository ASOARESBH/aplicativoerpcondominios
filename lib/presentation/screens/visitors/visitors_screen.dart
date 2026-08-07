import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class VisitorsScreen extends ConsumerStatefulWidget {
  const VisitorsScreen({super.key});

  @override
  ConsumerState<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends ConsumerState<VisitorsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _documentoController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _celularController = TextEditingController();
  final _emailController = TextEditingController();
  final _obsController = TextEditingController();
  String _tipoDocumento = 'CPF';
  bool _submitting = false;
  List<Map<String, dynamic>> _visitors = [];
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _documentoController.dispose();
    _telefoneController.dispose();
    _celularController.dispose();
    _emailController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _loadVisitors() async {
    setState(() => _loadingList = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.get(AppConstants.endpointPortal);
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        setState(() {
          _visitors = List<Map<String, dynamic>>.from(data['dados'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar visitantes: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _addVisitor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.post(
        AppConstants.endpointPortal,
        data: {
          'nome_completo': _nomeController.text,
          'tipo_documento': _tipoDocumento,
          'documento': _documentoController.text,
          'telefone': _telefoneController.text,
          'celular': _celularController.text,
          'email': _emailController.text,
          'observacao': _obsController.text,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['mensagem']?.toString() ?? ''),
            backgroundColor: data['sucesso'] == true ? AppTheme.success : AppTheme.danger,
          ),
        );
        if (data['sucesso'] == true) {
          _formKey.currentState!.reset();
          _nomeController.clear();
          _documentoController.clear();
          _telefoneController.clear();
          _celularController.clear();
          _emailController.clear();
          _obsController.clear();
          setState(() => _tipoDocumento = 'CPF');
          _loadVisitors();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteVisitor(int id, String nome) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Visitante'),
        content: Text('Deseja excluir "$nome"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.delete('${AppConstants.endpointPortal}&id=$id');
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['mensagem']?.toString() ?? ''),
            backgroundColor: data['sucesso'] == true ? AppTheme.success : AppTheme.danger,
          ),
        );
        if (data['sucesso'] == true) _loadVisitors();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadVisitors,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cadastrar Visitante
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_add, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cadastrar Visitante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Adicione visitantes autorizados', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nomeController,
                            decoration: const InputDecoration(labelText: 'Nome Completo *'),
                            validator: (v) => Validators.validateRequired(v, 'Nome'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _tipoDocumento,
                            decoration: const InputDecoration(labelText: 'Tipo de Documento *'),
                            items: ['CPF', 'RG', 'CNH', 'Passaporte']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) => setState(() => _tipoDocumento = v!),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _documentoController,
                            decoration: const InputDecoration(labelText: 'Número do Documento *'),
                            validator: (v) => Validators.validateRequired(v, 'Documento'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _telefoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(labelText: 'Telefone'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _celularController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(labelText: 'Celular'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'E-mail'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _obsController,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Observação'),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _addVisitor,
                              icon: _submitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.person_add),
                              label: const Text('Cadastrar Visitante'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Lista de visitantes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.list, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Text('Meus Visitantes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingList)
                      const Center(child: CircularProgressIndicator())
                    else if (_visitors.isEmpty)
                      const EmptyState(
                        icon: Icons.people_outline,
                        message: 'Nenhum visitante cadastrado.',
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _visitors.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final v = _visitors[index];
                          final isAtivo = v['ativo'] == 1 || v['ativo'] == true;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAtivo ? AppTheme.primaryLight : Colors.grey[200],
                              child: Icon(Icons.person, color: isAtivo ? AppTheme.primary : Colors.grey),
                            ),
                            title: Text(v['nome_completo']?.toString() ?? ''),
                            subtitle: Text('${v['tipo_documento']}: ${v['documento']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAtivo ? AppTheme.success.withOpacity(0.1) : AppTheme.danger.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isAtivo ? 'Ativo' : 'Inativo',
                                    style: TextStyle(
                                      color: isAtivo ? AppTheme.success : AppTheme.danger,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                                  onPressed: () => _deleteVisitor(
                                    int.tryParse(v['id'].toString()) ?? 0,
                                    v['nome_completo']?.toString() ?? '',
                                  ),
                                ),
                              ],
                            ),
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
