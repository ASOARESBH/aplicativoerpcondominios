import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/employee_auth_provider.dart';

class EmployeeVigilanteScreen extends ConsumerStatefulWidget {
  const EmployeeVigilanteScreen({super.key});

  @override
  ConsumerState<EmployeeVigilanteScreen> createState() =>
      _EmployeeVigilanteScreenState();
}

class _EmployeeVigilanteScreenState
    extends ConsumerState<EmployeeVigilanteScreen> {
  Map<String, dynamic>? _pontoLido;
  List<Map<String, dynamic>> _historico = const [];
  String? _tokenQr;
  String? _opcaoVigilante;
  String? _erroHistorico;
  bool _consultando = false;
  bool _registrando = false;
  bool _carregandoHistorico = true;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _lerQrCode() async {
    if (_consultando || _registrando) return;
    final token = await context.push<String>('/employee/scan');
    if (!mounted || token == null || token.trim().isEmpty) return;
    await _consultarPonto(token.trim());
  }

  Future<void> _consultarPonto(String token) async {
    final normalizado = token.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalizado)) {
      _show('QR Code inválido.', danger: true);
      return;
    }
    setState(() => _consultando = true);
    try {
      final response = await ref.read(employeeApiProvider).get(
        AppConstants.actionVigilanteQrDetalhe,
        queryParameters: {'token': normalizado},
      );
      final data = response.data;
      if (data is Map && data['sucesso'] == true && data['dados'] is Map) {
        final ponto = Map<String, dynamic>.from(data['dados']);
        if (!mounted) return;
        setState(() {
          _tokenQr = normalizado;
          _pontoLido = ponto;
          _opcaoVigilante = null;
        });
        await _confirmarLeitura();
      } else {
        _show(_message(data), danger: true);
      }
    } catch (error) {
      developer.log(
        'Consulta de QR de ronda falhou: ${error.runtimeType}',
        name: 'ColaboradorVigilante',
      );
      _show(_message(error), danger: true);
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _confirmarLeitura() async {
    final ponto = _pontoLido;
    if (ponto == null || !mounted) return;
    final requerSelecao = ponto['requer_selecao_vigilante'] == true;
    final opcoes = _asMapList(ponto['opcoes_vigilante']);
    if (requerSelecao && opcoes.isEmpty) {
      _show(
        ponto['mensagem_identidade']?.toString() ??
            'Não há vigilantes ativos vinculados a esta rota.',
        danger: true,
      );
      return;
    }

    var opcaoAtual = _opcaoVigilante;
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: !_registrando,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppTheme.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Confirmar leitura de ronda')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailLine('Ponto', _map(ponto['ponto'])['nome']),
                _detailLine('Local', _map(ponto['ponto'])['localizacao']),
                _detailLine('Rota', _map(ponto['rota'])['nome']),
                if ((_map(ponto['rota'])['hora_inicio']?.toString() ?? '')
                    .isNotEmpty)
                  _detailLine(
                    'Janela',
                    '${_map(ponto['rota'])['hora_inicio'] ?? '—'}'
                        ' a ${_map(ponto['rota'])['hora_fim'] ?? '—'}',
                  ),
                if ((ponto['instrucoes']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Instruções',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(ponto['instrucoes'].toString()),
                ],
                if (requerSelecao) ...[
                  const SizedBox(height: 18),
                  Text(
                    ponto['mensagem_identidade']?.toString() ??
                        'Confirme o vigilante responsável.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: opcaoAtual,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Vigilante responsável',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: opcoes
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item['opcao']?.toString(),
                            child: Text(
                              [
                                item['nome']?.toString() ?? 'Vigilante',
                                if ((item['cargo']?.toString() ?? '')
                                    .isNotEmpty)
                                  item['cargo'].toString(),
                              ].join(' — '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => opcaoAtual = value),
                  ),
                ] else if ((_map(ponto['vigilante'])['nome']?.toString() ?? '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _detailLine(
                    'Vigilante',
                    _map(ponto['vigilante'])['nome'],
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'A leitura será registrada sem localização GPS nesta versão. A câmera e o horário do servidor são usados para a operação.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: requerSelecao && opcaoAtual == null
                  ? null
                  : () {
                      setState(() => _opcaoVigilante = opcaoAtual);
                      Navigator.of(dialogContext).pop(true);
                    },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    if (confirmar == true && mounted) await _registrarLeitura();
  }

  Future<void> _registrarLeitura() async {
    if (_tokenQr == null || _pontoLido == null || _registrando) return;
    setState(() => _registrando = true);
    try {
      final response = await ref.read(employeeApiProvider).post(
        AppConstants.actionVigilanteRegistrarLeitura,
        data: {
          'token': _tokenQr,
          if (_opcaoVigilante != null) 'opcao_vigilante': _opcaoVigilante,
        },
      );
      final data = response.data;
      if (data is Map && data['sucesso'] == true) {
        final resultado = data['dados'] is Map
            ? Map<String, dynamic>.from(data['dados'])
            : const <String, dynamic>{};
        if (!mounted) return;
        await _mostrarResultado(data['mensagem']?.toString() ?? '', resultado);
        if (mounted) {
          setState(() {
            _pontoLido = null;
            _tokenQr = null;
            _opcaoVigilante = null;
          });
        }
        await _carregarHistorico();
      } else {
        _show(_message(data), danger: true);
      }
    } catch (error) {
      developer.log(
        'Registro de ronda falhou: ${error.runtimeType}',
        name: 'ColaboradorVigilante',
      );
      _show(_message(error), danger: true);
    } finally {
      if (mounted) setState(() => _registrando = false);
    }
  }

  Future<void> _mostrarResultado(
    String mensagem,
    Map<String, dynamic> resultado,
  ) async {
    final status = resultado['status_sla']?.toString() ?? '';
    final color = _slaColor(status);
    final titulo = status == 'atrasado'
        ? 'Leitura registrada com atraso'
        : 'Leitura registrada no prazo';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.task_alt_rounded, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(titulo)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensagem),
            const SizedBox(height: 12),
            _detailLine('Ponto', resultado['ponto']),
            _detailLine('Rota', resultado['rota']),
            if (status == 'atrasado')
              _detailLine(
                'Atraso',
                '${resultado['atraso_minutos'] ?? 0} minuto(s)',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _carregarHistorico() async {
    if (mounted) setState(() => _carregandoHistorico = true);
    try {
      final response = await ref
          .read(employeeApiProvider)
          .get(AppConstants.actionVigilanteHistoricoHoje);
      final data = response.data;
      if (data is Map && data['sucesso'] == true && data['dados'] is List) {
        if (mounted) {
          setState(() {
            _historico = _asMapList(data['dados']);
            _erroHistorico = null;
          });
        }
      } else if (mounted) {
        setState(() => _erroHistorico = _message(data));
      }
    } catch (error) {
      developer.log(
        'Histórico de rondas falhou: ${error.runtimeType}',
        name: 'ColaboradorVigilante',
      );
      if (mounted) setState(() => _erroHistorico = _message(error));
    } finally {
      if (mounted) setState(() => _carregandoHistorico = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _carregarHistorico,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Voltar ao painel',
                onPressed: () => context.go('/employee'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Text(
                'Vigilante',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: AppTheme.primary.withAlpha(14),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppTheme.primary, size: 42),
                  const SizedBox(height: 10),
                  const Text(
                    'Registrar ronda',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Leia o QR Code afixado no ponto. A rota, a janela e o SLA serão validados antes do registro.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed:
                          _consultando || _registrando ? null : _lerQrCode,
                      icon: _consultando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(
                        _consultando
                            ? 'Validando ponto...'
                            : 'Ler QR Code do ponto',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_pontoLido != null) ...[
            const SizedBox(height: 14),
            _pontoPendenteCard(),
          ],
          const SizedBox(height: 24),
          Text(
            'Histórico de hoje',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_carregandoHistorico)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erroHistorico != null)
            _historicoErroCard()
          else if (_historico.isEmpty)
            _historicoVazioCard()
          else
            ..._historico.map(_historicoCard),
        ],
      ),
    );
  }

  Widget _pontoPendenteCard() {
    final ponto = _pontoLido!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ponto pronto para confirmação',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _detailLine('Ponto', _map(ponto['ponto'])['nome']),
            _detailLine('Rota', _map(ponto['rota'])['nome']),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _registrando ? null : _confirmarLeitura,
              icon: _registrando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: const Text('Revisar e registrar leitura'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historicoCard(Map<String, dynamic> item) {
    final status = item['status_sla']?.toString() ?? '';
    final color = _slaColor(status);
    final tituloStatus = status == 'no_prazo'
        ? 'No prazo'
        : status == 'atrasado'
            ? 'Atrasado'
            : 'Registro manual';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(24),
          child: Icon(Icons.shield_outlined, color: color),
        ),
        title: Text(item['ponto']?.toString() ?? 'Ponto de ronda'),
        subtitle: Text(
          '${item['rota'] ?? 'Rota'}\n${_formatDateTime(item['registrado_em'])}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(tituloStatus,
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            if (status == 'atrasado')
              Text('${item['atraso_minutos'] ?? 0} min',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _historicoVazioCard() => const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.history_toggle_off_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text('Nenhuma leitura de ronda foi registrada hoje.'),
              ),
            ],
          ),
        ),
      );

  Widget _historicoErroCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.danger),
                  SizedBox(width: 8),
                  Text('Não foi possível carregar o histórico',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text(_erroHistorico!),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _carregarHistorico,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );

  Widget _detailLine(String label, dynamic value) {
    final texto = value?.toString().trim() ?? '';
    if (texto.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w700),
          children: [
            TextSpan(
                text: texto,
                style: const TextStyle(fontWeight: FontWeight.normal))
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  List<Map<String, dynamic>> _asMapList(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : const [];

  Color _slaColor(String status) {
    switch (status) {
      case 'no_prazo':
        return AppTheme.success;
      case 'atrasado':
        return Colors.orange.shade800;
      default:
        return AppTheme.danger;
    }
  }

  String _formatDateTime(dynamic value) {
    final texto = value?.toString() ?? '';
    if (texto.length >= 16) {
      return '${texto.substring(8, 10)}/${texto.substring(5, 7)} ${texto.substring(11, 16)}';
    }
    return texto.isEmpty ? 'Horário não informado' : texto;
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
    return 'Não foi possível concluir a operação de ronda.';
  }
}
