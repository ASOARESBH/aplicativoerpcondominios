import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  String _search = '';
  String _typeFilter = '';
  final _searchController = TextEditingController();

  @override
  void initState() { super.initState(); _loadData(); }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      final params = <String, String>{'acao': 'documentos_listar'};
      if (_search.isNotEmpty) params['busca'] = _search;
      if (_typeFilter.isNotEmpty) params['tipo'] = _typeFilter;
      final response = await dioClient.dio.get(AppConstants.endpointDocumentos, queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        final dados = data['dados'];
        if (dados is List) {
          setState(() => _documents = List<Map<String, dynamic>>.from(dados));
        } else if (dados is Map && dados['documentos'] != null) setState(() => _documents = List<Map<String, dynamic>>.from(dados['documentos']));
      }
    } catch (e) { debugPrint('[DocumentsScreen] Error: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  IconData _getFileIcon(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'word': return Icons.description;
      case 'excel': return Icons.table_chart;
      case 'imagem': return Icons.image;
      case 'zip': return Icons.folder_zip;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'pdf': return AppTheme.danger;
      case 'word': return AppTheme.primary;
      case 'excel': return AppTheme.success;
      case 'imagem': return AppTheme.warning;
      default: return Colors.grey;
    }
  }

  Future<void> _openDocument(Map<String, dynamic> doc) async {
    try {
      final dioClient = ref.read(dioClientProvider);
      final baseUrl = AppConstants.baseUrl;
      final id = doc['id'];
      final url = '$baseUrl${AppConstants.endpointDocumentos}?acao=download&id=$id';
      final token = await ref.read(secureStorageProvider).getAuthToken();
      // Try to open with URL launcher (authenticated URL)
      final uri = Uri.parse('$url&token=$token');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir documento: $e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Pesquisar documentos...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _search = ''); _loadData(); }) : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: (v) { setState(() => _search = v); if (v.length >= 3 || v.isEmpty) _loadData(); },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['', 'pdf', 'word', 'excel', 'imagem'].map((t) {
                    final labels = {'': 'Todos', 'pdf': 'PDF', 'word': 'Word', 'excel': 'Excel', 'imagem': 'Imagem'};
                    final isSelected = t == _typeFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () { setState(() => _typeFilter = t); _loadData(); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(color: isSelected ? AppTheme.primary : AppTheme.primaryLight, borderRadius: BorderRadius.circular(16)),
                          child: Text(labels[t]!, style: TextStyle(color: isSelected ? Colors.white : AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                    ? const EmptyState(icon: Icons.folder_open, message: 'Nenhum documento encontrado.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _documents.length,
                        itemBuilder: (context, index) {
                          final doc = _documents[index];
                          final tipo = doc['tipo']?.toString();
                          return Card(
                            child: ListTile(
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: _getFileColor(tipo).withAlpha(26), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_getFileIcon(tipo), color: _getFileColor(tipo)),
                              ),
                              title: Text(doc['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (doc['pasta_nome'] != null) Text(doc['pasta_nome'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(doc['data_upload']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              trailing: IconButton(icon: const Icon(Icons.download, color: AppTheme.primary), onPressed: () => _openDocument(doc)),
                              onTap: () => _openDocument(doc),
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
