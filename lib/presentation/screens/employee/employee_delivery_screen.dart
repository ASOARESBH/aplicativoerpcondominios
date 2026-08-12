import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/employee_auth_provider.dart';

class EmployeeDeliveryScreen extends ConsumerStatefulWidget {
  const EmployeeDeliveryScreen({this.initialProtocol, super.key});

  final Map<String, dynamic>? initialProtocol;

  @override
  ConsumerState<EmployeeDeliveryScreen> createState() =>
      _EmployeeDeliveryScreenState();
}

class _EmployeeDeliveryScreenState
    extends ConsumerState<EmployeeDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _recipientController = TextEditingController();
  final _cpfController = TextEditingController();
  Map<String, dynamic>? _protocol;
  bool _lookingUp = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _protocol = widget.initialProtocol;
    if (_protocol != null) {
      _codeController.text = _protocol!['codigo_nf']?.toString() ??
          'PROTOCOLO:${_protocol!['id'] ?? ''}';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _recipientController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _scanAndLookup() async {
    final code = await context.push<String>('/employee/scan');
    if (code == null || code.trim().isEmpty || !mounted) return;
    _codeController.text = code.trim();
    await _lookup();
  }

  Future<void> _lookup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _lookingUp) {
      _show('Leia ou informe o QR Code/código da mercadoria.', danger: true);
      return;
    }
    setState(() => _lookingUp = true);
    try {
      final response = await ref.read(employeeApiProvider).get(
        AppConstants.actionBuscarProtocoloQr,
        queryParameters: {'codigo': code},
      );
      final data = response.data;
      if (data is Map && data['sucesso'] == true && data['dados'] is Map) {
        final protocol = Map<String, dynamic>.from(data['dados']);
        if (protocol['status']?.toString() == 'entregue') {
          _show('Esta mercadoria já foi entregue.', danger: true);
          return;
        }
        if (mounted) {
          setState(() => _protocol = protocol);
          _show('Mercadoria localizada. Confirme a identidade do recebedor.');
        }
      } else {
        setState(() => _protocol = null);
        _show(_message(data), danger: true);
      }
    } catch (error) {
      developer.log('Busca QR falhou: ${error.runtimeType}',
          name: 'ColaboradorEntrega');
      _show(_message(error), danger: true);
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _deliver() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _protocol == null || _saving) {
      if (_protocol == null)
        _show('Localize a mercadoria antes de confirmar.', danger: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await ref.read(employeeApiProvider).post(
        AppConstants.actionEntregarProtocolo,
        data: {
          'protocolo_id': int.tryParse(_protocol!['id'].toString()) ?? 0,
          'nome_recebedor': _recipientController.text.trim(),
          'cpf_confirmacao': _cpfController.text.replaceAll(RegExp(r'\D'), ''),
        },
      );
      final data = response.data;
      if (data is Map && data['sucesso'] == true) {
        _show('Entrega confirmada. O morador foi notificado.');
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
              'Entregar mercadoria',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'QR Code, rastreio ou número do protocolo',
                    prefixIcon: const Icon(Icons.qr_code_rounded),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ler pela câmera',
                          onPressed: _scanAndLookup,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                        ),
                        IconButton(
                          tooltip: 'Buscar mercadoria',
                          onPressed: _lookingUp ? null : _lookup,
                          icon: _lookingUp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search_rounded),
                        ),
                      ],
                    ),
                  ),
                  onSubmitted: (_) => _lookup(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Leia a etiqueta para abrir diretamente a mercadoria e o morador destinatário.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (_protocol != null) ...[
          const SizedBox(height: 16),
          _protocolCard(),
          const SizedBox(height: 16),
          _authenticationForm(),
        ],
      ],
    );
  }

  Widget _protocolCard() {
    final protocol = _protocol!;
    return Card(
      color: AppTheme.primary.withAlpha(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Mercadoria localizada',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const Divider(height: 24),
            Text(protocol['descricao_mercadoria']?.toString() ?? 'Mercadoria',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Morador: ${protocol['morador_nome'] ?? '—'}'),
            Text('Unidade: ${protocol['unidade_nome'] ?? '—'}'),
            if ((protocol['codigo_nf']?.toString() ?? '').isNotEmpty)
              Text('Código: ${protocol['codigo_nf']}'),
            Text('Recebida em: ${protocol['data_hora_recebimento'] ?? '—'}'),
          ],
        ),
      ),
    );
  }

  Widget _authenticationForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppTheme.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Confirmação de entrega',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Confirme o CPF completo do morador responsável antes de entregar. O nome do recebedor fica registrado na auditoria.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recipientController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome de quem recebeu',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe quem recebeu a mercadoria'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 11,
                decoration: const InputDecoration(
                  labelText: 'CPF do morador responsável',
                  hintText: 'Somente números',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) =>
                    (value?.replaceAll(RegExp(r'\D'), '').length ?? 0) != 11
                        ? 'Informe os 11 dígitos do CPF'
                        : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _deliver,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.task_alt_rounded),
                  label: Text(_saving ? 'Confirmando...' : 'Confirmar entrega'),
                ),
              ),
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
    return 'Não foi possível concluir a entrega.';
  }
}
