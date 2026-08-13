import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

/// Lista plana de documentos GED visíveis ao morador autenticado.
///
/// A API `buscar` já aplica a autorização no servidor pelo token Bearer e
/// pesquisa documentos em todas as pastas. Esta tela nunca informa tenant,
/// unidade, morador ou pasta ao servidor.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  static const _pageSize = 30;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _search = '';
  String _typeFilter = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore ||
        _scrollController.position.extentAfter > 280) {
      return;
    }
    _loadData(reset: false);
  }

  Future<void> _loadData({bool reset = true}) async {
    if (_loadingMore || (!reset && (!_hasMore || _loading))) return;

    final requestedPage = reset ? 1 : _page + 1;
    if (mounted) {
      setState(() {
        if (reset) {
          _loading = true;
          _errorMessage = null;
        } else {
          _loadingMore = true;
        }
      });
    }

    try {
      final dioClient = ref.read(dioClientProvider);
      final params = <String, dynamic>{
        'acao': 'buscar',
        'q': _search.trim(),
        'pagina': requestedPage,
      };
      if (_typeFilter.isNotEmpty) params['tipo'] = _typeFilter;

      final response = await dioClient.dio.get(
        AppConstants.endpointDocumentos,
        queryParameters: params,
      );
      final rawData = response.data;
      if (rawData is! Map) {
        throw const FormatException('A API retornou uma resposta inválida.');
      }

      final data = Map<String, dynamic>.from(rawData);
      if (data['sucesso'] != true) {
        throw Exception(
          data['mensagem']?.toString() ??
              'Não foi possível consultar os documentos.',
        );
      }

      final dados = data['dados'];
      final rawDocuments = dados is Map ? dados['documentos'] : null;
      if (rawDocuments is! List) {
        throw const FormatException(
            'A API não retornou a lista de documentos.');
      }

      final received = rawDocuments
          .whereType<Map>()
          .map<Map<String, dynamic>>(
              (document) => Map<String, dynamic>.from(document))
          .toList();

      if (!mounted) return;
      setState(() {
        final current = reset ? <Map<String, dynamic>>[] : [..._documents];
        final knownIds = current.map((doc) => doc['id']?.toString()).toSet();
        for (final document in received) {
          final id = document['id']?.toString();
          if (id == null || !knownIds.contains(id)) {
            current.add(document);
            if (id != null) knownIds.add(id);
          }
        }
        _documents = current;
        _page = requestedPage;
        _hasMore = received.length >= _pageSize;
        _errorMessage = null;
      });
      debugPrint(
        '[DocumentsScreen] pagina=$requestedPage recebidos=${received.length} total=${_documents.length}',
      );
    } catch (error) {
      debugPrint('[DocumentsScreen] consulta falhou: $error');
      if (!mounted) return;
      final message = _friendlyError(error);
      setState(() {
        if (reset) _errorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '');
    if (value.contains('SocketException') ||
        value.contains('NetworkException')) {
      return 'Sem conexão com a internet. Tente novamente quando a rede voltar.';
    }
    if (value.contains('TimeoutException')) {
      return 'A consulta demorou demais. Tente novamente.';
    }
    return value.isEmpty ? 'Não foi possível consultar os documentos.' : value;
  }

  void _onSearchChanged(String value) {
    _search = value;
    _searchDebounce?.cancel();
    if (value.trim().isNotEmpty && value.trim().length < 3) return;
    _searchDebounce = Timer(const Duration(milliseconds: 400), _loadData);
  }

  IconData _getFileIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'word':
        return Icons.description;
      case 'excel':
        return Icons.table_chart;
      case 'imagem':
        return Icons.image;
      case 'zip':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'pdf':
        return AppTheme.danger;
      case 'word':
        return AppTheme.primary;
      case 'excel':
        return AppTheme.success;
      case 'imagem':
        return AppTheme.warning;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    final id = document['id'];
    if (id == null) {
      _showOpenError('Documento inválido. Atualize a lista e tente novamente.');
      return;
    }

    try {
      final token = await ref.read(secureStorageProvider).getAuthToken();
      final uri = Uri.parse(
        '${AppConstants.baseUrl}${AppConstants.endpointDocumentos}'
        '?acao=download&id=$id&token=${Uri.encodeQueryComponent(token ?? '')}',
      );
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _showOpenError('Não foi possível abrir este documento.');
    } catch (error) {
      debugPrint('[DocumentsScreen] abertura falhou: $error');
      _showOpenError('Erro ao abrir documento: ${_friendlyError(error)}');
    }
  }

  void _showOpenError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
    );
  }

  String _dateLabel(Map<String, dynamic> document) {
    final raw = document['data_publicacao'] ??
        document['data_upload'] ??
        document['atualizado_em'];
    final value = raw?.toString() ?? '';
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          color: colorScheme.surface,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Pesquisar documentos...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                            _loadData();
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['', 'pdf', 'word', 'excel', 'imagem'].map((type) {
                    final labels = {
                      '': 'Todos',
                      'pdf': 'PDF',
                      'word': 'Word',
                      'excel': 'Excel',
                      'imagem': 'Imagem',
                    };
                    final selected = type == _typeFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _typeFilter = type);
                          _loadData();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            labels[type]!,
                            style: TextStyle(
                              color: selected ? Colors.white : AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null && _documents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 88),
            Icon(Icons.cloud_off, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ),
          ],
        ),
      );
    }

    if (_documents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 90),
            EmptyState(
              icon: Icons.folder_open,
              message: 'Nenhum documento encontrado.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _documents.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : const Text('Role para carregar mais documentos.'),
              ),
            );
          }

          final document = _documents[index];
          final type =
              document['categoria']?.toString() ?? document['tipo']?.toString();
          return Card(
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getFileColor(type).withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getFileIcon(type), color: _getFileColor(type)),
              ),
              title: Text(
                document['nome']?.toString() ?? 'Documento sem nome',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (document['pasta_nome'] != null &&
                      document['pasta_nome'].toString().isNotEmpty)
                    Text(
                      document['pasta_nome'].toString(),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  if (_dateLabel(document).isNotEmpty)
                    Text(
                      _dateLabel(document),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.download, color: AppTheme.primary),
                tooltip: 'Abrir ou baixar documento',
                onPressed: () => _openDocument(document),
              ),
              onTap: () => _openDocument(document),
            ),
          );
        },
      ),
    );
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
