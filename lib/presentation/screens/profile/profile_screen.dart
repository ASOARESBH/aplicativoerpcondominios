import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/input_formatters.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../../data/models/morador_model.dart';

final _profileDataProvider = FutureProvider<MoradorModel?>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return null;
  final dioClient = ref.read(dioClientProvider);
  await dioClient.initBaseUrl();
  try {
    final response = await dioClient.dio.get(AppConstants.endpointProfile);
    final data = response.data as Map<String, dynamic>;
    if (data['sucesso'] == true && data['dados'] != null) {
      return MoradorModel.fromJson(data['dados'] as Map<String, dynamic>);
    }
  } catch (_) {}
  return null;
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _telefoneController = TextEditingController();
  final _celularController = TextEditingController();
  final _senhaAtualController = TextEditingController();
  final _senhaNovController = TextEditingController();
  final _senhaConfirmarController = TextEditingController();
  bool _savingPhone = false;
  bool _savingPassword = false;
  bool _obscureSenhaAtual = true;
  bool _obscureSenhaNova = true;
  bool _obscureSenhaConfirmar = true;

  @override
  void dispose() {
    _telefoneController.dispose();
    _celularController.dispose();
    _senhaAtualController.dispose();
    _senhaNovController.dispose();
    _senhaConfirmarController.dispose();
    super.dispose();
  }

  Future<void> _savePhone() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    setState(() => _savingPhone = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final response = await dioClient.dio.put(
        AppConstants.endpointProfile,
        data: {
          'telefone': _telefoneController.text,
          'celular': _celularController.text,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['mensagem']?.toString() ?? ''),
            backgroundColor: data['sucesso'] == true ? AppTheme.success : AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPhone = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    if (_senhaNovController.text != _senhaConfirmarController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('As senhas não coincidem.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    setState(() => _savingPassword = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final response = await dioClient.dio.put(
        AppConstants.endpointProfile,
        data: {
          'senha_atual': _senhaAtualController.text,
          'senha_nova': _senhaNovController.text,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['mensagem']?.toString() ?? ''),
            backgroundColor: data['sucesso'] == true ? AppTheme.success : AppTheme.danger,
          ),
        );
        if (data['sucesso'] == true) {
          _senhaAtualController.clear();
          _senhaNovController.clear();
          _senhaConfirmarController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_profileDataProvider);
    final authState = ref.watch(authProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_profileDataProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: profileAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => ErrorState(
            message: 'Erro ao carregar perfil.',
            onRetry: () => ref.invalidate(_profileDataProvider),
          ),
          data: (morador) {
            if (morador != null) {
              // Preencher campos de telefone
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_telefoneController.text.isEmpty) {
                  _telefoneController.text = morador.telefone ?? '';
                }
                if (_celularController.text.isEmpty) {
                  _celularController.text = morador.celular ?? '';
                }
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Senha temporária warning
                if (authState.session?.senhaTemporaria == true)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warning),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber, color: AppTheme.warning),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Você está usando uma senha temporária. Altere sua senha para continuar.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Dados do perfil
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.badge, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Meus Dados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Informações cadastrais', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(label: 'Nome', value: morador?.nome ?? '—'),
                        _InfoRow(label: 'CPF', value: morador?.cpf ?? '—'),
                        _InfoRow(label: 'Unidade', value: morador?.unidade ?? '—'),
                        _InfoRow(label: 'E-mail', value: morador?.email ?? '—'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Atualizar contatos
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _phoneFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.phone, color: AppTheme.primary),
                              SizedBox(width: 10),
                              Text('Atualizar Contatos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _telefoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhoneInputFormatter()],
                            decoration: const InputDecoration(labelText: 'Telefone Fixo'),
                            validator: Validators.validatePhone,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _celularController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhoneInputFormatter()],
                            decoration: const InputDecoration(labelText: 'Celular / WhatsApp'),
                            validator: Validators.validatePhone,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _savingPhone ? null : _savePhone,
                              icon: _savingPhone
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('Salvar Contatos'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Alterar senha
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _passwordFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock, color: AppTheme.primary),
                              SizedBox(width: 10),
                              Text('Alterar Senha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _senhaAtualController,
                            obscureText: _obscureSenhaAtual,
                            decoration: InputDecoration(
                              labelText: 'Senha Atual',
                              suffixIcon: IconButton(
                                icon: Icon(_obscureSenhaAtual ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureSenhaAtual = !_obscureSenhaAtual),
                              ),
                            ),
                            validator: (v) => Validators.validateRequired(v, 'Senha atual'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _senhaNovController,
                            obscureText: _obscureSenhaNova,
                            decoration: InputDecoration(
                              labelText: 'Nova Senha',
                              suffixIcon: IconButton(
                                icon: Icon(_obscureSenhaNova ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureSenhaNova = !_obscureSenhaNova),
                              ),
                            ),
                            validator: Validators.validatePassword,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _senhaConfirmarController,
                            obscureText: _obscureSenhaConfirmar,
                            decoration: InputDecoration(
                              labelText: 'Confirmar Nova Senha',
                              suffixIcon: IconButton(
                                icon: Icon(_obscureSenhaConfirmar ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureSenhaConfirmar = !_obscureSenhaConfirmar),
                              ),
                            ),
                            validator: Validators.validatePassword,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _savingPassword ? null : _changePassword,
                              icon: _savingPassword
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.key),
                              label: const Text('Alterar Senha'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
