import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int _tabIndex = 0;
  List<Map<String, dynamic>> _orders = [];
  bool _loadingOrders = false;

  @override
  void initState() { super.initState(); _loadVitrine(); }

  Future<void> _loadVitrine() async {
    setState(() => _loading = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final response = await dioClient.dio.get('${AppConstants.endpointMarketplace}?acao=vitrine');
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        final dados = data['dados'];
        if (dados is Map && dados['itens'] != null) {
          setState(() => _items = List<Map<String, dynamic>>.from(dados['itens']));
        } else if (dados is List) setState(() => _items = List<Map<String, dynamic>>.from(dados));
      }
    } catch (e) { debugPrint('[MarketplaceScreen] Error: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final response = await dioClient.dio.get('${AppConstants.endpointMarketplace}?acao=meus_pedidos');
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) setState(() => _orders = List<Map<String, dynamic>>.from(data['dados'] ?? []));
    } catch (e) { debugPrint('[MarketplaceScreen] Orders error: $e'); }
    finally { if (mounted) setState(() => _loadingOrders = false); }
  }

  void _openContractModal(Map<String, dynamic> item) {
    final descController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Text(item['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
            const SizedBox(height: 4),
            Text(item['fornecedor_nome']?.toString() ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(controller: descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Descreva sua necessidade *')),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (descController.text.trim().isEmpty) return;
                Navigator.pop(context);
                try {
                  final dioClient = ref.read(dioClientProvider);
                  await dioClient.initBaseUrl();
                  final fd = {'acao': 'contratar', 'produto_servico_id': item['id'], 'descricao_pedido': descController.text};
                  final response = await dioClient.dio.post(AppConstants.endpointMarketplace, data: fd);
                  final data = response.data as Map<String, dynamic>;
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['mensagem']?.toString() ?? ''), backgroundColor: data['sucesso'] == true ? AppTheme.success : AppTheme.danger));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.danger));
                }
              },
              icon: const Icon(Icons.handshake),
              label: const Text('Enviar Solicitação'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: Row(
            children: [
              Expanded(child: GestureDetector(onTap: () { setState(() => _tabIndex = 0); _loadVitrine(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tabIndex == 0 ? AppTheme.primary : Colors.transparent, width: 2))), child: Text('Vitrine', textAlign: TextAlign.center, style: TextStyle(color: _tabIndex == 0 ? AppTheme.primary : Colors.grey, fontWeight: FontWeight.w600))))),
              Expanded(child: GestureDetector(onTap: () { setState(() => _tabIndex = 1); _loadOrders(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tabIndex == 1 ? AppTheme.primary : Colors.transparent, width: 2))), child: Text('Meus Pedidos', textAlign: TextAlign.center, style: TextStyle(color: _tabIndex == 1 ? AppTheme.primary : Colors.grey, fontWeight: FontWeight.w600))))),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _tabIndex == 0
              ? RefreshIndicator(
                  onRefresh: _loadVitrine,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? const EmptyState(icon: Icons.store, message: 'Nenhuma oferta disponível.')
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                final valor = item['valor'] != null ? 'R\$ ${double.tryParse(item['valor'].toString())?.toStringAsFixed(2) ?? item['valor']}' : 'A combinar';
                                return Card(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _openContractModal(item),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            height: 80, width: double.infinity,
                                            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                                            child: const Icon(Icons.store, size: 36, color: AppTheme.primary),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(item['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(item['fornecedor_nome']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const Spacer(),
                                          Text(valor, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 6),
                                          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _openContractModal(item), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)), child: const Text('Contratar', style: TextStyle(fontSize: 12)))),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: _loadingOrders
                      ? const Center(child: CircularProgressIndicator())
                      : _orders.isEmpty
                          ? const EmptyState(icon: Icons.shopping_bag, message: 'Nenhum pedido encontrado.')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _orders.length,
                              itemBuilder: (context, index) {
                                final o = _orders[index];
                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(backgroundColor: AppTheme.primaryLight, child: Icon(Icons.shopping_bag, color: AppTheme.primary)),
                                    title: Text(o['produto_nome']?.toString() ?? o['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                    subtitle: Text('Status: ${o['status'] ?? ''} · ${o['data_pedido']?.toString().substring(0, 10) ?? ''}'),
                                  ),
                                );
                              },
                            ),
                ),
        ),
      ],
    );
  }
}

void debugPrint(String message) { print(message); }
