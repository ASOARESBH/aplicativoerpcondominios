import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/employee_auth_provider.dart';

class EmployeeReceiveProtocolScreen extends ConsumerStatefulWidget {
  const EmployeeReceiveProtocolScreen({super.key});

  @override
  ConsumerState<EmployeeReceiveProtocolScreen> createState() =>
      _EmployeeReceiveProtocolScreenState();
}

class _EmployeeReceiveProtocolScreenState
    extends ConsumerState<EmployeeReceiveProtocolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _residentSearchController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();
  final _pageController = TextEditingController();
  final _observationController = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _residents = const [];
  Map<String, dynamic>? _selectedResident;
  DateTime _receivedAt = DateTime.now();
  bool _searching = false;
  bool _saving = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _residentSearchController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    _pageController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  void _onResidentSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _residents = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchResidents(value);
    });
  }

  Future<void> _searchResidents(String text) async {
    setState(() => _searching = true);
    try {
      final response = await ref.read(employeeApiProvider).get(
        AppConstants.actionMoradoresColaborador,
        queryParameters: {'busca': text.trim(), 'limite': 15},
      );
      final data = response.data;
      if (data is Map && data['sucesso'] == true && data['dados'] is List) {
        if (mounted) {
          setState(
            () => _residents = data['dados']
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          );
        }
      }
    } catch (error) {
      developer.log('Busca de moradores falhou: ${error.runtimeType}',
          name: 'ColaboradorRecebimento');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _scanCode() async {
    final code = await context.push<String>('/employee/scan');
    if (code != null && code.trim().isNotEmpty && mounted) {
      setState(() => _codeController.text = code.trim());
      _show('Código lido pela câmera. Confira os dados antes de salvar.');
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _receivedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_receivedAt),
    );
    if (time == null) return;
    setState(
      () => _receivedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() ||
        _selectedResident == null ||
        _saving) {
      if (_selectedResident == null) {
        _show('Selecione o morador destinatário.', danger: true);
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await ref.read(employeeApiProvider).post(
        AppConstants.actionReceberProtocolo,
        data: {
          'morador_id': int.tryParse(_selectedResident!['id'].toString()) ?? 0,
          'descricao_mercadoria': _descriptionController.text.trim(),
          'codigo_nf': _codeController.text.trim(),
          'pagina': int.tryParse(_pageController.text.trim()),
          'data_hora_recebimento': _formatDateTime(_receivedAt),
          'observacao': _observationController.text.trim(),
        },
      );
      final data = response.data;
      if (data is Map && data['sucesso'] == true) {
        _show('Mercadoria registrada e morador notificado.');
        if (mounted) context.go('/employee/protocols');
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
    final date = _formatDisplayDate(_receivedAt);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Voltar para protocolos',
              onPressed: () => context.go('/employee/protocols'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Text(
              'Receber mercadoria',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'O usuário conectado será gravado automaticamente como recebedor na portaria.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _residentSearchController,
                    onChanged: _onResidentSearchChanged,
                    decoration: InputDecoration(
                      labelText: 'Buscar morador ou unidade',
                      prefixIcon: const Icon(Icons.person_search_outlined),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (_selectedResident != null) ...[
                    const SizedBox(height: 8),
                    _selectedResidentCard(),
                  ],
                  if (_residents.isNotEmpty && _selectedResident == null) ...[
                    const SizedBox(height: 8),
                    _residentSuggestions(),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Descrição da mercadoria',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe a descrição da mercadoria'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeController,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: 'Código, rastreio ou nota fiscal',
                      prefixIcon:
                          const Icon(Icons.confirmation_number_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Ler QR Code pela câmera',
                        onPressed: _scanCode,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Página',
                            hintText: 'Opcional',
                            prefixIcon: Icon(Icons.menu_book_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateTime,
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(date),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(55),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observationController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      hintText: 'Opcional',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
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
                          : const Icon(Icons.save_alt_rounded),
                      label: Text(_saving
                          ? 'Registrando recebimento...'
                          : 'Registrar recebimento'),
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

  Widget _residentSuggestions() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: _residents
            .map(
              (resident) => ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(resident['nome']?.toString() ?? 'Morador'),
                subtitle: Text(resident['unidade']?.toString() ?? ''),
                onTap: () => setState(() {
                  _selectedResident = resident;
                  _residentSearchController.text =
                      resident['nome']?.toString() ?? '';
                  _residents = const [];
                }),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _selectedResidentCard() {
    final resident = _selectedResident!;
    return Card(
      color: AppTheme.success.withAlpha(22),
      child: ListTile(
        leading:
            const Icon(Icons.verified_user_outlined, color: AppTheme.success),
        title: Text(resident['nome']?.toString() ?? 'Morador'),
        subtitle: Text('Unidade: ${resident['unidade'] ?? '—'}'),
        trailing: IconButton(
          tooltip: 'Alterar morador',
          onPressed: () => setState(() {
            _selectedResident = null;
            _residentSearchController.clear();
          }),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  String _formatDisplayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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
    return 'Não foi possível concluir a operação.';
  }
}
