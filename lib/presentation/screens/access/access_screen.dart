import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class AccessScreen extends ConsumerStatefulWidget {
  const AccessScreen({super.key});

  @override
  ConsumerState<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends ConsumerState<AccessScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedVisitorId;
  String _tipoVisitante = 'visitante';
  String _tipoAcesso = 'portaria';
  final _placaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _corController = TextEditingController();
  DateTime? _dataInicial;
  DateTime? _dataFinal;
  List<Map<String, dynamic>> _visitors = [];
  List<Map<String, dynamic>> _accesses = [];
  bool _submitting = false;
  bool _loadingList = true;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _placaController.dispose();
    _modeloController.dispose();
    _corController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingList = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final authState = ref.read(authProvider);
      final moradorId = authState.session?.moradorId;

      final results = await Future.wait([
        dioClient.dio.get(AppConstants.endpointVisitors),
        dioClient.dio.get('${AppConstants.endpointAccess}?morador_id=$moradorId'),
      ]);

      final visitorsData = results[0].data as Map<String, dynamic>;
      final accessData = results[1].data as Map<String, dynamic>;

      setState(() {
        _visitors = List<Map<String, dynamic>>.from(visitorsData['dados'] ?? []);
        _accesses = List<Map<String, dynamic>>.from(accessData['dados'] ?? []);
      });
    } catch (e) {
      debugPrint('[AccessScreen] Error loading data: $e');
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _generateAccess() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataInicial == null || _dataFinal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione as datas de início e fim.'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    if (_dataFinal!.isBefore(_dataInicial!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data final deve ser maior que a inicial.'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final authState = ref.read(authProvider);

      final response = await dioClient.dio.post(
        AppConstants.endpointAccess,
        data: {
          'visitante_id': _selectedVisitorId,
          'tipo_visitante': _tipoVisitante,
          'placa': _placaController.text.isEmpty ? null : _placaController.text.toUpperCase(),
          'modelo': _modeloController.text.isEmpty ? null : _modeloController.text,
          'cor': _corController.text.isEmpty ? null : _corController.text,
          'data_inicial': _dataInicial!.toIso8601String().split('T')[0],
          'data_final': _dataFinal!.toIso8601String().split('T')[0],
          'tipo_acesso': _tipoAcesso,
          'morador_id': authState.session?.moradorId,
          'unidade_destino': authState.session?.unidade,
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
          _formKey.currentState!.reset();
          setState(() {
            _selectedVisitorId = null;
            _tipoVisitante = 'visitante';
            _tipoAcesso = 'portaria';
            _dataInicial = null;
            _dataFinal = null;
          });
          _placaController.clear();
          _modeloController.clear();
          _corController.clear();
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showQrCode(int accessId) async {
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final baseUrl = await ref.read(secureStorageProvider).getBaseUrl();
      final qrUrl = '$baseUrl/api/api_acessos_visitantes.php?action=gerar_qrcode&id=$accessId';

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('QR Code de Acesso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: qrUrl,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text(
                'Apresente este QR Code na portaria para autorizar a entrada.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar QR Code: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteAccess(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Acesso'),
        content: const Text('Deseja revogar este acesso?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final response = await dioClient.dio.delete('${AppConstants.endpointAccess}?id=$id');
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['mensagem']?.toString() ?? ''),
            backgroundColor: data['sucesso'] == true ? AppTheme.success : AppTheme.danger,
          ),
        );
        if (data['sucesso'] == true) _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? now : (_dataInicial ?? now),
      firstDate: isStart ? now : (_dataInicial ?? now),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _dataInicial = picked;
          if (_dataFinal != null && _dataFinal!.isBefore(picked)) _dataFinal = null;
        } else {
          _dataFinal = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gerar QR Code
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
                          decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.qr_code, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gerar QR Code de Acesso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Autorize a entrada de visitantes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          DropdownButtonFormField<int>(
                            value: _selectedVisitorId,
                            decoration: const InputDecoration(labelText: 'Visitante *'),
                            items: _visitors
                                .map((v) => DropdownMenuItem<int>(
                                      value: int.tryParse(v['id'].toString()),
                                      child: Text('${v['nome_completo']} — ${v['tipo_documento']}: ${v['documento']}'),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedVisitorId = v),
                            validator: (v) => v == null ? 'Selecione um visitante' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _tipoVisitante,
                            decoration: const InputDecoration(labelText: 'Tipo de Visitante *'),
                            items: const [
                              DropdownMenuItem(value: 'visitante', child: Text('Visitante')),
                              DropdownMenuItem(value: 'prestador', child: Text('Prestador de Serviço')),
                            ],
                            onChanged: (v) => setState(() => _tipoVisitante = v!),
                          ),
                          const SizedBox(height: 16),
                          const Align(alignment: Alignment.centerLeft, child: Text('Dados do Veículo', style: TextStyle(fontWeight: FontWeight.w600))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _placaController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(labelText: 'Placa'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _modeloController,
                                  decoration: const InputDecoration(labelText: 'Modelo'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _corController,
                                  decoration: const InputDecoration(labelText: 'Cor'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Align(alignment: Alignment.centerLeft, child: Text('Período', style: TextStyle(fontWeight: FontWeight.w600))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickDate(true),
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(_dataInicial == null
                                      ? 'Data Inicial *'
                                      : '${_dataInicial!.day.toString().padLeft(2, '0')}/${_dataInicial!.month.toString().padLeft(2, '0')}/${_dataInicial!.year}'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickDate(false),
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(_dataFinal == null
                                      ? 'Data Final *'
                                      : '${_dataFinal!.day.toString().padLeft(2, '0')}/${_dataFinal!.month.toString().padLeft(2, '0')}/${_dataFinal!.year}'),
                                ),
                              ),
                            ],
                          ),
                          if (_dataInicial != null && _dataFinal != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_dataFinal!.difference(_dataInicial!).inDays + 1} dias de permanência',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Align(alignment: Alignment.centerLeft, child: Text('Tipo de Acesso *', style: TextStyle(fontWeight: FontWeight.w600))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _TipoAcessoButton(label: 'Portaria', icon: Icons.door_front_door, value: 'portaria', selected: _tipoAcesso, onTap: (v) => setState(() => _tipoAcesso = v)),
                              const SizedBox(width: 8),
                              _TipoAcessoButton(label: 'Externo', icon: Icons.route, value: 'externo', selected: _tipoAcesso, onTap: (v) => setState(() => _tipoAcesso = v)),
                              const SizedBox(width: 8),
                              _TipoAcessoButton(label: 'Lagoa', icon: Icons.water, value: 'lagoa', selected: _tipoAcesso, onTap: (v) => setState(() => _tipoAcesso = v)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _generateAccess,
                              icon: _submitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.qr_code),
                              label: const Text('Gerar QR Code'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Lista de acessos
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
                          decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.list_alt, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Text('Meus Acessos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingList)
                      const Center(child: CircularProgressIndicator())
                    else if (_accesses.isEmpty)
                      const EmptyState(icon: Icons.qr_code_2, message: 'Nenhum acesso gerado.')
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _accesses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final a = _accesses[index];
                          final isAtivo = a['ativo'] == 1 || a['ativo'] == true;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAtivo ? AppTheme.primaryLight : Colors.grey[200],
                              child: Icon(Icons.qr_code, color: isAtivo ? AppTheme.primary : Colors.grey),
                            ),
                            title: Text(a['visitante_nome']?.toString() ?? ''),
                            subtitle: Text('${a['data_inicial']} a ${a['data_final']} · ${a['tipo_acesso']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.qr_code, color: AppTheme.primary),
                                  onPressed: () => _showQrCode(int.tryParse(a['id'].toString()) ?? 0),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                                  onPressed: () => _deleteAccess(int.tryParse(a['id'].toString()) ?? 0),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipoAcessoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _TipoAcessoButton({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppTheme.primary : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppTheme.primary, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
