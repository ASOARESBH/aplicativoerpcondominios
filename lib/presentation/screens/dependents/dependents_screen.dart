import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class DependentsScreen extends ConsumerStatefulWidget {
  const DependentsScreen({super.key});

  @override
  ConsumerState<DependentsScreen> createState() => _DependentsScreenState();
}

class _DependentsScreenState extends ConsumerState<DependentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _celularController = TextEditingController();
  final _obsController = TextEditingController();
  String _parentesco = '';
  DateTime? _dataNascimento;
  bool _submitting = false;
  List<Map<String, dynamic>> _dependents = [];
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _loadDependents();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _emailController.dispose();
    _celularController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _loadDependents() async {
    setState(() => _loadingList = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.get(AppConstants.endpointDependentes, queryParameters: {'action': 'listar'});
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        setState(() => _dependents = List<Map<String, dynamic>>.from(data['dados'] ?? []));
      }
    } catch (e) {
      debugPrint('[DependentsScreen] Error: $e');
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _addDependent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.post(
        '${AppConstants.endpointDependentes}?action=criar',
        data: {
          'nome_completo': _nomeController.text,
          'parentesco': _parentesco,
          'cpf': _cpfController.text,
          'data_nascimento': _dataNascimento?.toIso8601String().split('T')[0],
          'email': _emailController.text,
          'celular': _celularController.text,
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
          _cpfController.clear();
          _emailController.clear();
          _celularController.clear();
          _obsController.clear();
          setState(() { _parentesco = ''; _dataNascimento = null; });
          _loadDependents();
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

  Future<void> _deleteDependent(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Dependente'),
        content: const Text('Deseja excluir este dependente?'),
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
      final response = await dioClient.dio.delete(AppConstants.endpointDependentes, queryParameters: {'action': 'excluir', 'id': id});
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['mensagem']?.toString() ?? ''),
            backgroundColor: data['sucesso'] == true ? AppTheme.success : AppTheme.danger,
          ),
        );
        if (data['sucesso'] == true) _loadDependents();
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
      onRefresh: _loadDependents,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                    const Row(
                      children: [
                        Icon(Icons.family_restroom, color: AppTheme.primary),
                        SizedBox(width: 10),
                        Text('Cadastrar Dependente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                            value: _parentesco.isEmpty ? null : _parentesco,
                            decoration: const InputDecoration(labelText: 'Parentesco'),
                            items: ['Cônjuge', 'Filho(a)', 'Pai/Mãe', 'Irmão(ã)', 'Outro']
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) => setState(() => _parentesco = v ?? ''),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cpfController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'CPF'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime(2000),
                                      firstDate: DateTime(1900),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) setState(() => _dataNascimento = picked);
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(_dataNascimento == null
                                      ? 'Nascimento'
                                      : '${_dataNascimento!.day.toString().padLeft(2, '0')}/${_dataNascimento!.month.toString().padLeft(2, '0')}/${_dataNascimento!.year}'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(labelText: 'E-mail'),
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
                            controller: _obsController,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Observação'),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _addDependent,
                              icon: _submitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.person_add),
                              label: const Text('Cadastrar Dependente'),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people, color: AppTheme.primary),
                        SizedBox(width: 10),
                        Text('Meus Dependentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingList)
                      const Center(child: CircularProgressIndicator())
                    else if (_dependents.isEmpty)
                      const EmptyState(icon: Icons.family_restroom, message: 'Nenhum dependente cadastrado.')
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _dependents.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final d = _dependents[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.primaryLight,
                              child: Icon(Icons.person, color: AppTheme.primary),
                            ),
                            title: Text(d['nome_completo']?.toString() ?? ''),
                            subtitle: Text([d['parentesco'], d['celular']].where((e) => e != null && e.toString().isNotEmpty).join(' · ')),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                              onPressed: () => _deleteDependent(int.tryParse(d['id'].toString()) ?? 0),
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

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
