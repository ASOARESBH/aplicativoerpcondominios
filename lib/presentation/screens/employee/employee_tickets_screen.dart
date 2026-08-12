import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/employee_auth_provider.dart';

class EmployeeTicketsScreen extends ConsumerStatefulWidget {
  const EmployeeTicketsScreen({this.openForm = false, super.key});

  final bool openForm;

  @override
  ConsumerState<EmployeeTicketsScreen> createState() =>
      _EmployeeTicketsScreenState();
}

class _EmployeeTicketsScreenState extends ConsumerState<EmployeeTicketsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _tickets = const [];
  List<Map<String, dynamic>> _subjects = const [];
  bool _loading = true;
  bool _saving = false;
  int? _subjectId;
  String _department = '';
  String _priority = 'media';

  @override
  void initState() {
    super.initState();
    if (!widget.openForm) _loadTickets();
    _loadSubjects();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _loading = true);
    try {
      final response = await ref
          .read(employeeApiProvider)
          .get(AppConstants.actionChamadosColaborador);
      final data = response.data;
      if (data is Map && data['sucesso'] == true && data['dados'] is List) {
        if (mounted) {
          setState(
            () => _tickets = data['dados']
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          );
        }
      } else {
        _show(_message(data), danger: true);
      }
    } catch (error) {
      _show(_message(error), danger: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSubjects() async {
    try {
      final response = await ref
          .read(employeeApiProvider)
          .get(AppConstants.actionAssuntosColaborador);
      final data = response.data;
      if (data is Map && data['sucesso'] == true && data['dados'] is List) {
        if (mounted) {
          setState(
            () => _subjects = data['dados']
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          );
        }
      }
    } catch (error) {
      developer.log('Falha ao carregar assuntos: ${error.runtimeType}',
          name: 'Colaborador');
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final response = await ref.read(employeeApiProvider).post(
        AppConstants.actionAbrirChamadoColaborador,
        data: {
          'titulo': _titleController.text.trim(),
          'descricao': _descriptionController.text.trim(),
          'assunto_id': _subjectId ?? 0,
          'departamento': _department,
          'prioridade': _priority,
        },
      );
      final data = response.data;
      if (data is Map && data['sucesso'] == true) {
        final number = (data['dados'] as Map?)?['numero']?.toString() ?? '';
        _show(
          number.isEmpty
              ? 'Chamado aberto com sucesso.'
              : 'Chamado $number aberto com sucesso.',
        );
        if (mounted) context.go('/employee/tickets');
      } else {
        _show(_message(data), danger: true);
      }
    } catch (error) {
      _show(_message(error), danger: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.openForm) return _buildForm(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/employee/tickets/new'),
        icon: const Icon(Icons.add),
        label: const Text('Abrir chamado'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tickets.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Icon(Icons.support_agent_outlined, size: 64),
                      SizedBox(height: 12),
                      Center(child: Text('Você ainda não abriu chamados.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _ticketCard(_tickets[index]),
                  ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.go('/employee/tickets'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Text(
              'Abrir chamado',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Título do chamado',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe o título'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _subjectId,
                    decoration: const InputDecoration(
                      labelText: 'Assunto',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Não especificado'),
                      ),
                      ..._subjects.map(
                        (subject) => DropdownMenuItem<int>(
                          value: int.tryParse(subject['id']?.toString() ?? ''),
                          child: Text(subject['nome']?.toString() ?? 'Assunto'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      final subject = _subjects.where(
                        (item) => item['id']?.toString() == value?.toString(),
                      );
                      setState(() {
                        _subjectId = value;
                        _department = subject.isEmpty
                            ? ''
                            : subject.first['departamento']?.toString() ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Prioridade',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
                      DropdownMenuItem(value: 'media', child: Text('Média')),
                      DropdownMenuItem(value: 'alta', child: Text('Alta')),
                      DropdownMenuItem(
                          value: 'urgente', child: Text('Urgente')),
                    ],
                    onChanged: (value) =>
                        setState(() => _priority = value ?? 'media'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 92),
                        child: Icon(Icons.notes_rounded),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Descreva o chamado'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_saving ? 'Enviando...' : 'Abrir chamado'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ticketCard(Map<String, dynamic> ticket) {
    final status = ticket['status']?.toString() ?? 'aberto';
    final statusColor = switch (status) {
      'finalizado' => AppTheme.success,
      'cancelado' => AppTheme.danger,
      'andamento' => AppTheme.warning,
      _ => AppTheme.primary,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(25),
          child: Icon(Icons.support_agent_outlined, color: statusColor),
        ),
        title: Text(
          ticket['titulo']?.toString() ?? 'Chamado',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${ticket['numero'] ?? '—'} • ${status.toUpperCase()}\n${ticket['data_abertura'] ?? ''}',
        ),
        isThreeLine: true,
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
    if (value is Map && value['mensagem'] != null)
      return value['mensagem'].toString();
    return value.toString().replaceFirst('Exception: ', '');
  }
}
