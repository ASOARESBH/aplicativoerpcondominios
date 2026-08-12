import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = const [];
  bool _isLoading = true;
  bool _isSavingPreference = false;
  bool _deviceAlertsEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadNotifications(), _loadDevicePreference()]);
  }

  Future<void> _loadDevicePreference() async {
    final enabled =
        await ref.read(notificationManagerProvider).areDeviceAlertsEnabled();
    if (mounted) {
      setState(() => _deviceAlertsEnabled = enabled);
    }
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.get(
        AppConstants.endpointPortal,
        queryParameters: {
          'action': AppConstants.actionNotificacoes,
          'limite': 50,
        },
      );
      final data = response.data;
      if (data is! Map || data['sucesso'] != true) {
        throw Exception(data is Map
            ? data['mensagem']?.toString()
            : 'Resposta inválida do servidor.');
      }
      final payload = data['dados'];
      final rawNotifications = payload is Map ? payload['notificacoes'] : null;
      final list = rawNotifications is List
          ? rawNotifications
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _notifications = list);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDeviceAlerts(bool enable) async {
    if (_isSavingPreference) return;
    setState(() => _isSavingPreference = true);

    try {
      final manager = ref.read(notificationManagerProvider);
      String message;
      bool effectiveValue = _deviceAlertsEnabled;

      if (enable) {
        final result = await manager.enableDeviceAlerts();
        effectiveValue = result.enabled;
        message = result.message;
      } else {
        await manager.disableDeviceAlerts();
        effectiveValue = false;
        message =
            'Alertas no dispositivo desabilitados. As encomendas continuam na lista desta tela.';
      }

      if (mounted) {
        setState(() => _deviceAlertsEnabled = effectiveValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor:
                effectiveValue ? AppTheme.success : AppTheme.warning,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(error)),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPreference = false);
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final isRead = _asBool(notification['lida']);
    if (isRead) return;

    final id = int.tryParse(notification['id']?.toString() ?? '');
    if (id == null) return;

    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.post(
        AppConstants.endpointPortal,
        queryParameters: {'action': AppConstants.actionMarcarNotificacaoLida},
        data: {'notificacao_id': id},
      );
      final data = response.data;
      if (data is Map && data['sucesso'] != true) {
        throw Exception(data['mensagem']?.toString() ??
            'Não foi possível marcar como lida.');
      }
      if (mounted) {
        setState(() => notification['lida'] = 1);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_friendlyError(error)),
              backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final pending =
        _notifications.where((item) => !_asBool(item['lida'])).toList();
    for (final item in pending) {
      await _markAsRead(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _notifications.where((item) => !_asBool(item['lida'])).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _isLoading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
          if (unreadCount > 0)
            TextButton(
              onPressed: _isLoading ? null : _markAllAsRead,
              child: const Text(
                'Ler todas',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildDeviceAlertsCard(),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 72),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ErrorState(message: _error!, onRetry: _loadAll)
            else if (_notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 64),
                child: EmptyState(
                  icon: Icons.notifications_none_outlined,
                  message: 'Nenhuma notificação de encomenda até o momento.',
                ),
              )
            else ...[
              Text(
                unreadCount > 0
                    ? '$unreadCount aviso${unreadCount == 1 ? '' : 's'} não lido${unreadCount == 1 ? '' : 's'}'
                    : 'Todos os avisos foram lidos',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      unreadCount > 0 ? AppTheme.primary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 10),
              ..._notifications.map(_buildNotificationCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceAlertsCard() {
    return Card(
      color: _deviceAlertsEnabled ? AppTheme.primaryLight : null,
      child: SwitchListTile.adaptive(
        value: _deviceAlertsEnabled,
        onChanged: _isSavingPreference ? null : _toggleDeviceAlerts,
        secondary: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (_deviceAlertsEnabled ? AppTheme.primary : Colors.grey)
                .withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _deviceAlertsEnabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            color: _deviceAlertsEnabled ? AppTheme.primary : Colors.grey,
          ),
        ),
        title: const Text(
          'Alertas no dispositivo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _isSavingPreference
              ? 'Atualizando preferência...'
              : _deviceAlertsEnabled
                  ? 'Você será avisado quando uma encomenda chegar ou for entregue.'
                  : 'Ative para receber avisos no display do celular.',
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = _asBool(notification['lida']);
    final type = notification['tipo']?.toString() ?? '';
    final isDelivered = type == 'mercadoria_entregue';
    final title = notification['titulo']?.toString() ??
        (isDelivered ? 'Mercadoria recebida' : 'Sua encomenda chegou');
    final body = notification['mensagem']?.toString() ?? '';
    final timestamp = _formatDate(notification['criado_em']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: isRead ? null : AppTheme.primaryLight,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _markAsRead(notification),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDelivered ? AppTheme.success : AppTheme.primary)
                        .withAlpha(28),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDelivered
                        ? Icons.task_alt_outlined
                        : Icons.inventory_2_outlined,
                    color: isDelivered ? AppTheme.success : AppTheme.primary,
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
                              title,
                              style: TextStyle(
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(body,
                          style: const TextStyle(fontSize: 13, height: 1.35)),
                      const SizedBox(height: 7),
                      Text(
                        timestamp,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _asBool(dynamic value) => value == true || value == 1 || value == '1';

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Agora';
    final date = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    return date == null ? raw : DateFormat('dd/MM/yyyy • HH:mm').format(date);
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('401')) {
      return 'Sua sessão expirou. Entre novamente para consultar as notificações.';
    }
    return text.isEmpty ? 'Não foi possível carregar as notificações.' : text;
  }
}
