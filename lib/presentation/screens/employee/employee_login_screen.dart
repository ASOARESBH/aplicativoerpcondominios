import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/employee_auth_provider.dart';

class EmployeeLoginScreen extends ConsumerStatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  ConsumerState<EmployeeLoginScreen> createState() =>
      _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends ConsumerState<EmployeeLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login([int? tenantId]) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(employeeAuthProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          tenantId: tenantId,
        );
    if (success && mounted) context.go('/employee');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeAuthProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2B52), AppTheme.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 14,
                  shadowColor: Colors.black45,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 54,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Portal do Colaborador',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Acesso operacional para chamados, protocolos e entregas.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 28),
                          _field(
                            controller: _emailController,
                            label: 'E-mail corporativo',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty || !email.contains('@')) {
                                return 'Informe seu e-mail corporativo';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _field(
                            controller: _passwordController,
                            label: 'Senha',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            suffix: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Informe sua senha'
                                    : null,
                          ),
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _MessageBox(
                              message: state.errorMessage!,
                              color: AppTheme.danger,
                            ),
                          ],
                          if (state.requiresTenantSelection) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Selecione o condomínio autorizado',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            ...state.availableTenants.map(
                              (tenant) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: OutlinedButton.icon(
                                  onPressed: state.isLoading
                                      ? null
                                      : () => _login(
                                            int.tryParse(
                                                  tenant['id']?.toString() ??
                                                      '',
                                                ) ??
                                                0,
                                          ),
                                  icon: const Icon(Icons.apartment_outlined),
                                  label: Text(
                                    tenant['nome']?.toString() ?? 'Condomínio',
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: state.isLoading ? null : _login,
                              icon: state.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                state.isLoading
                                    ? 'Validando acesso...'
                                    : 'Entrar como colaborador',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => context.go('/login'),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Voltar ao Portal do Morador'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscure = false,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      onFieldSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: const TextStyle(color: Colors.black87),
      cursorColor: AppTheme.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: Colors.black54),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        border: Border.all(color: color.withAlpha(90)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
