import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Histórico somente-leitura dos acessos destinados à unidade do morador.
/// A API determina unidade e tenant exclusivamente pelo token Bearer da sessão.
class AccessControlScreen extends ConsumerStatefulWidget {
  const AccessControlScreen({super.key});

  @override
  ConsumerState<AccessControlScreen> createState() =>
      _AccessControlScreenState();
}

class _AccessControlScreenState extends ConsumerState<AccessControlScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  List<Map<String, dynamic>> _accesses = const [];
  bool _isLoading = true;
  String? _error;
  String _selectedType = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _unit;

  @override
  void initState() {
    super.initState();
    _loadAccesses();
  }

  Future<void> _loadAccesses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await ref.read(dioClientProvider).dio.get(
        AppConstants.endpointPortal,
        queryParameters: {
          'action': AppConstants.actionControleAcesso,
          'limite': 100,
          if (_selectedType.isNotEmpty) 'tipo': _selectedType,
          if (_startDate != null)
            'data_inicio': _dateFormat.format(_startDate!),
          if (_endDate != null) 'data_fim': _dateFormat.format(_endDate!),
        },
      );
      final data = response.data;
      if (data is! Map || data['sucesso'] != true) {
        throw Exception(data is Map
            ? data['mensagem']?.toString() ?? 'Resposta inválida do servidor.'
            : 'Resposta inválida do servidor.');
      }
      final payload = data['dados'];
      final rawAccesses = payload is Map ? payload['acessos'] : null;
      final accesses = rawAccesses is List
          ? rawAccesses
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        debugPrint(
          '[ControleAcesso] ${accesses.length} registro(s) carregado(s); '
          'tipo=${_selectedType.isEmpty ? 'todos' : _selectedType}.',
        );
        setState(() {
          _accesses = accesses;
          _unit = payload is Map ? payload['unidade']?.toString() : null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: isStart ? 'Data inicial' : 'Data final',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
    _loadAccesses();
  }

  void _clearFilters() {
    setState(() {
      _selectedType = '';
      _startDate = null;
      _endDate = null;
    });
    _loadAccesses();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        _selectedType.isNotEmpty || _startDate != null || _endDate != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Acesso'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _isLoading ? null : _loadAccesses,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAccesses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildIntroCard(),
            const SizedBox(height: 14),
            _buildFilters(hasFilters),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 72),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildError()
            else if (_accesses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 64),
                child: _AccessEmptyState(),
              )
            else ...[
              Text(
                '${_accesses.length} acesso${_accesses.length == 1 ? '' : 's'} encontrado${_accesses.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ..._accesses.map(_buildAccessCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E3A5F) : AppTheme.primaryLight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined,
                color: AppTheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acessos da sua unidade',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _unit == null || _unit!.isEmpty
                        ? 'Acompanhe entradas e saídas destinadas ao seu imóvel.'
                        : 'Histórico destinado à unidade $_unit.',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(bool hasFilters) {
    const options = ['', 'Morador', 'Visitante', 'Prestador'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('Filtros',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (hasFilters)
                  TextButton(
                    onPressed: _isLoading ? null : _clearFilters,
                    child: const Text('LIMPAR'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (type) => ChoiceChip(
                      label: Text(type.isEmpty ? 'Todos' : type),
                      selected: _selectedType == type,
                      onSelected: _isLoading
                          ? null
                          : (_) {
                              setState(() => _selectedType = type);
                              _loadAccesses();
                            },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _dateButton('De', _startDate, () => _pickDate(isStart: true)),
                _dateButton('Até', _endDate, () => _pickDate(isStart: false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onPressed) {
    final text =
        date == null ? label : '$label ${DateFormat('dd/MM').format(date)}';
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text(text),
    );
  }

  Widget _buildAccessCard(Map<String, dynamic> access) {
    final isExit = access['tipo_acesso']?.toString().toLowerCase() == 'saída';
    final type = access['tipo']?.toString() ?? 'Acesso';
    final name = access['nome']?.toString() ?? 'Acesso identificado';
    final plate = access['placa']?.toString().trim() ?? '';
    final date = access['data_hora_formatada']?.toString() ??
        access['data_hora']?.toString() ??
        'Data não informada';
    final accent = isExit ? AppTheme.warning : AppTheme.success;
    final status = access['status']?.toString().trim() ?? '';
    final model = access['modelo']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: accent.withAlpha(28),
              child: Icon(
                isExit ? Icons.logout_rounded : Icons.login_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plate.isEmpty ? name : plate,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      _statusChip(isExit ? 'Saída' : 'Entrada', accent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plate.isEmpty || model.isEmpty ? name : '$name • $model',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    children: [
                      _metadata(Icons.badge_outlined, type),
                      _metadata(Icons.schedule_outlined, date),
                    ],
                  ),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _metadata(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loadAccesses,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('TENTAR NOVAMENTE'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['mensagem'] != null) {
        return data['mensagem'].toString();
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Não foi possível conectar ao servidor. Verifique sua internet.';
      }
    }
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty
        ? 'Não foi possível carregar o histórico de acessos.'
        : text;
  }
}

class _AccessEmptyState extends StatelessWidget {
  const _AccessEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.shield_outlined, size: 56, color: Colors.grey),
        SizedBox(height: 12),
        Text(
          'Nenhum acesso foi registrado para sua unidade no período selecionado.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
