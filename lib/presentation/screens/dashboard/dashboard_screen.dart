import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';

/// Tela inicial (Dashboard) do Portal do Morador.
/// Exibe dados da sessão local — sem chamada de rede ao abrir.
/// O morador vê imediatamente suas informações após o login.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).session;

    final List<_MenuCard> cards = [
      _MenuCard(icon: Icons.people_outline,        label: 'Visitantes',      route: '/home/visitors',    color: const Color(0xFF4CAF50)),
      _MenuCard(icon: Icons.qr_code_scanner,       label: 'Acessos',         route: '/home/access',      color: const Color(0xFF2196F3)),
      _MenuCard(icon: Icons.family_restroom,        label: 'Dependentes',     route: '/home/dependents',  color: const Color(0xFF9C27B0)),
      _MenuCard(icon: Icons.water_drop_outlined,   label: 'Hidrômetro',      route: '/home/water-meter', color: const Color(0xFF00BCD4)),
      _MenuCard(icon: Icons.directions_car_outlined,label: 'Veículos',        route: '/home/vehicles',    color: const Color(0xFFFF9800)),
      _MenuCard(icon: Icons.build_outlined,        label: 'Chamados',        route: '/home/tickets',     color: const Color(0xFFF44336)),
      _MenuCard(icon: Icons.description_outlined,  label: 'Protocolos',      route: '/home/protocols',   color: const Color(0xFF607D8B)),
      _MenuCard(icon: Icons.folder_outlined,       label: 'Documentos',      route: '/home/documents',   color: const Color(0xFF795548)),
      _MenuCard(icon: Icons.construction_outlined, label: 'Projetos',        route: '/home/projects',    color: const Color(0xFF009688)),
      _MenuCard(icon: Icons.store_outlined,        label: 'Marketplace',     route: '/home/marketplace', color: const Color(0xFFE91E63)),
      _MenuCard(icon: Icons.person_outline,        label: 'Meu Perfil',      route: '/home/profile',     color: AppTheme.primary),
      _MenuCard(icon: Icons.notifications_outlined,label: 'Notificações',    route: '/home/notifications',color: const Color(0xFFFF5722)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Boas-vindas
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(80),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, ${_firstName(session?.nome)}!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session?.unidade != null
                            ? 'Unidade ${session!.unidade}'
                            : AppConstants.appName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Serviços',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Grid de módulos
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return _buildMenuCard(context, card);
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, _MenuCard card) {
    return InkWell(
      onTap: () => context.go(card.route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: card.color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(card.icon, color: card.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              card.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _firstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'Morador';
    return fullName.split(' ').first;
  }
}

class _MenuCard {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _MenuCard({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}
