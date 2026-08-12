import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

/// Tela de Login — Portal do Morador ERP Condomínios
///
/// MULTI-TENANT: URL FIXA https://app.erpcondominios.com.br/
/// Todos os condomínios usam a mesma URL.
/// O tenant é identificado pelo token Bearer gerado no login.
/// NÃO há campo de URL customizada nesta tela.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _obscureSenha = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _senhaController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final cpf = _cpfController.text.trim();
    final senha = _senhaController.text;

    await ref.read(authProvider.notifier).login(
          cpf: cpf,
          password: senha,
        );

    // Push é complementar e nunca pode reter a navegação pós-login.
    // O roteador reage ao estado autenticado; esta sincronização ocorre em
    // segundo plano e qualquer falha fica isolada do fluxo principal.
    if (ref.read(authProvider).isAuthenticated) {
      unawaited(
        ref.read(notificationManagerProvider).syncAfterAuthenticatedSession(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final isLoading = authState.isLoading;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Fundo gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.primary, AppTheme.primaryDark],
              ),
            ),
          ),

          // Conteúdo
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // ── Logo ──────────────────────────────────────────
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.apartment_rounded,
                            color: AppTheme.primary,
                            size: 64,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Título ────────────────────────────────────────
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Portal do Morador',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── Card de Login ─────────────────────────────────
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 12,
                        shadowColor: Colors.black26,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Cabeçalho do card
                                Text(
                                  'Entrar',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryDark,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Informe seu CPF e senha',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 24),

                                // ── Campo CPF ─────────────────────────
                                TextFormField(
                                  controller: _cpfController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  // Garante texto visível em qualquer tema
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    letterSpacing: 1.5,
                                  ),
                                  cursorColor: AppTheme.primary,
                                  decoration: InputDecoration(
                                    labelText: 'CPF',
                                    labelStyle:
                                        const TextStyle(color: Colors.black54),
                                    hintText: '000.000.000-00',
                                    hintStyle:
                                        const TextStyle(color: Colors.black38),
                                    prefixIcon: const Icon(
                                      Icons.person_outline_rounded,
                                      color: Colors.black54,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.black26),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.black26),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: AppTheme.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Informe seu CPF';
                                    }
                                    final digits = v.replaceAll(
                                      RegExp(r'[^\d]'),
                                      '',
                                    );
                                    if (digits.length != 11) {
                                      return 'CPF deve ter 11 dígitos';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // ── Campo Senha ───────────────────────
                                TextFormField(
                                  controller: _senhaController,
                                  obscureText: _obscureSenha,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handleLogin(),
                                  // Garante texto visível em qualquer tema
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                  ),
                                  cursorColor: AppTheme.primary,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    labelStyle:
                                        const TextStyle(color: Colors.black54),
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Colors.black54,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.black26),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.black26),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: AppTheme.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureSenha
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.black54,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureSenha = !_obscureSenha,
                                      ),
                                      tooltip: _obscureSenha
                                          ? 'Mostrar senha'
                                          : 'Ocultar senha',
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Informe sua senha';
                                    }
                                    if (v.length < 4) {
                                      return 'Senha muito curta';
                                    }
                                    return null;
                                  },
                                ),

                                // Esqueci a senha
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        context.push('/forgot-password'),
                                    child: const Text('Esqueci minha senha'),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // ── Mensagem de erro ──────────────────
                                if (authState.status == AuthStatus.error &&
                                    authState.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.danger.withAlpha(20),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.danger.withAlpha(80),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppTheme.danger,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            authState.errorMessage!,
                                            style: const TextStyle(
                                              color: AppTheme.danger,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // ── Botão Entrar ──────────────────────
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 3,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Entrar',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Rodapé com versão e URL do sistema
                      Column(
                        children: [
                          Text(
                            'v${AppConstants.appVersion}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'app.erpcondominios.com.br',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
