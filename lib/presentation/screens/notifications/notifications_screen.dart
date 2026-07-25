import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common/loading_overlay.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Notificações são gerenciadas pelo Firebase Cloud Messaging
  // Esta tela exibe as notificações recebidas localmente
  final List<Map<String, dynamic>> _notifications = [
    {'title': 'Bem-vindo ao ERP Condomínios!', 'body': 'Seu aplicativo está configurado e pronto para uso.', 'time': 'Agora', 'icon': Icons.apartment, 'read': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _notifications.forEach((n) => n['read'] = true)),
              child: const Text('Marcar todas como lidas', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              message: 'Nenhuma notificação recebida.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final n = _notifications[index];
                final isRead = n['read'] as bool;
                return Card(
                  color: isRead ? null : AppTheme.primaryLight,
                  child: ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isRead ? Colors.grey[200] : AppTheme.primary.withAlpha(26),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(n['icon'] as IconData, color: isRead ? Colors.grey : AppTheme.primary),
                    ),
                    title: Text(n['title'] as String, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n['body'] as String, style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(n['time'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    onTap: () => setState(() => n['read'] = true),
                    trailing: !isRead ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)) : null,
                  ),
                );
              },
            ),
    );
  }
}
