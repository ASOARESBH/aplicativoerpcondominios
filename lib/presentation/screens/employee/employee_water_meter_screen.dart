import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/offline/water_meter_offline_service.dart';
import '../../../core/offline/water_meter_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/employee_auth_provider.dart';

class EmployeeWaterMeterScreen extends ConsumerStatefulWidget {
  const EmployeeWaterMeterScreen({super.key});

  @override
  ConsumerState<EmployeeWaterMeterScreen> createState() =>
      _EmployeeWaterMeterScreenState();
}

class _EmployeeWaterMeterScreenState
    extends ConsumerState<EmployeeWaterMeterScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  bool _loadingMeters = false;
  List<Map<String, dynamic>> _residents = const [];
  List<Map<String, dynamic>> _meters = const [];
  Map<String, dynamic>? _resident;
  final _offline = WaterMeterOfflineService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  int _pendingCount = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPending();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        _synchronize(silent: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _synchronize(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _offline.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _residents = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  int? get _tenantId {
    final tenant = ref.read(employeeAuthProvider).session?['tenant'];
    return tenant is Map ? int.tryParse(tenant['id'].toString()) : null;
  }

  Future<void> _refreshPending() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    final count = await _offline.pendingCount(tenantId: tenantId);
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _synchronize({bool silent = false}) async {
    final tenantId = _tenantId;
    if (tenantId == null || _syncing) return;
    setState(() => _syncing = true);
    try {
      final summary = await WaterMeterSyncService(
        ref.read(employeeApiProvider),
        _offline,
      ).syncPending(tenantId: tenantId);
      await _refreshPending();
      if (!silent && mounted) {
        final message = summary.offline
            ? 'Sem conexão. As leituras pendentes permanecem guardadas no aparelho.'
            : summary.synced > 0
                ? '${summary.synced} leitura(s) sincronizada(s).'
                : summary.failed > 0
                    ? '${summary.failed} leitura(s) continuam pendentes para nova tentativa.'
                    : 'Não há leituras pendentes para sincronizar.';
        _show(message, danger: summary.failed > 0);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _search(String term) async {
    setState(() => _searching = true);
    try {
      final response = await ref.read(employeeApiProvider).get(
        AppConstants.actionMoradoresColaborador,
        queryParameters: {'busca': term.trim(), 'limite': 20},
      );
      final data = response.data;
      if (data is Map &&
          data['sucesso'] == true &&
          data['dados'] is List &&
          mounted) {
        setState(
          () => _residents = (data['dados'] as List)
              .whereType<Map>()
              .map((item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)))
              .toList(),
        );
      }
    } catch (error) {
      developer.log('Falha na busca de morador: ${error.runtimeType}',
          name: 'Leiturista');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectResident(Map<String, dynamic> resident) async {
    setState(() {
      _resident = resident;
      _residents = const [];
      _meters = const [];
      _searchController.text = resident['nome']?.toString() ?? '';
      _loadingMeters = true;
    });
    try {
      final response = await ref.read(employeeApiProvider).get(
        AppConstants.actionHidrometrosLeiturista,
        queryParameters: {'morador_id': resident['id']},
      );
      final data = response.data;
      if (data is Map &&
          data['sucesso'] == true &&
          data['dados'] is List &&
          mounted) {
        setState(
          () => _meters = (data['dados'] as List)
              .whereType<Map>()
              .map((item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)))
              .toList(),
        );
      } else {
        _show(_message(data), danger: true);
      }
    } catch (error) {
      developer.log('Falha ao consultar hidrômetros: $error',
          name: 'Leiturista');
      _show(_message(error), danger: true);
    } finally {
      if (mounted) setState(() => _loadingMeters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Leitura de hidrômetros',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Sincronizar pendências',
              onPressed: _syncing ? null : () => _synchronize(),
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Badge(
                      isLabelVisible: _pendingCount > 0,
                      label: Text('$_pendingCount'),
                      child: const Icon(Icons.sync_rounded),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Selecione um morador e registre a leitura individual do medidor ativo.',
        ),
        const SizedBox(height: 12),
        if (_pendingCount > 0)
          Card(
            color: Colors.amber.withAlpha(22),
            child: ListTile(
              leading:
                  const Icon(Icons.cloud_upload_outlined, color: Colors.amber),
              title: Text('$_pendingCount leitura(s) aguardando sincronização'),
              subtitle: const Text(
                  'As fotos estão guardadas no armazenamento privado do aparelho.'),
              trailing: TextButton(
                onPressed: _syncing ? null : () => _synchronize(),
                child: const Text('SINCRONIZAR'),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    labelText: 'Buscar morador ou unidade',
                    hintText: 'Digite ao menos 2 caracteres',
                    prefixIcon: const Icon(Icons.person_search_outlined),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                if (_residents.isNotEmpty && _resident == null) ...[
                  const SizedBox(height: 8),
                  _suggestions(),
                ],
                if (_resident != null) ...[
                  const SizedBox(height: 10),
                  _residentCard(),
                ],
              ],
            ),
          ),
        ),
        if (_resident != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Hidrômetros da unidade',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingMeters)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ))
          else if (_meters.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'Nenhum hidrômetro ativo foi encontrado para este morador.'),
              ),
            )
          else
            ..._meters.map(_meterCard),
        ],
      ],
    );
  }

  Widget _suggestions() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: _residents
            .map(
              (resident) => ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(resident['nome']?.toString() ?? 'Morador'),
                subtitle: Text('Unidade: ${resident['unidade'] ?? '—'}'),
                onTap: () => _selectResident(resident),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _residentCard() {
    return Card(
      color: AppTheme.success.withAlpha(20),
      child: ListTile(
        leading:
            const Icon(Icons.verified_user_outlined, color: AppTheme.success),
        title: Text(_resident!['nome']?.toString() ?? 'Morador'),
        subtitle: Text('Unidade: ${_resident!['unidade'] ?? '—'}'),
        trailing: IconButton(
          tooltip: 'Alterar morador',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() {
            _resident = null;
            _meters = const [];
            _searchController.clear();
          }),
        ),
      ),
    );
  }

  Widget _meterCard(Map<String, dynamic> meter) {
    final previous =
        double.tryParse(meter['leitura_anterior']?.toString() ?? '') ?? 0;
    final hasReading = meter['leitura_no_mes']?.toString() == '1';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasReading
            ? null
            : () => context.push(
                  '/employee/water-meter/read',
                  extra: {
                    'resident': _resident,
                    'meter': meter,
                  },
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    (hasReading ? Colors.grey : AppTheme.primary).withAlpha(24),
                child: Icon(
                  hasReading ? Icons.task_alt_rounded : Icons.speed_rounded,
                  color: hasReading ? Colors.grey : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hidrômetro ${meter['numero_hidrometro'] ?? '—'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('Lacre: ${meter['numero_lacre'] ?? 'Não informado'}'),
                    Text('Última leitura: ${previous.toStringAsFixed(3)} m³'),
                    if (meter['data_ultima_leitura'] != null)
                      Text('Lançada em: ${meter['data_ultima_leitura']}'),
                    const SizedBox(height: 5),
                    Text(
                      hasReading
                          ? 'Leitura desta competência já lançada'
                          : 'Toque para lançar a leitura',
                      style: TextStyle(
                        color: hasReading ? Colors.grey : AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!hasReading) const Icon(Icons.chevron_right_rounded),
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
    return 'Não foi possível consultar os hidrômetros.';
  }
}
