import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.initBaseUrl();
      final response = await dioClient.dio.get(AppConstants.endpointProjects);
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        final rawData = data['dados'];
        if (rawData is List) {
          setState(() => _items = List<Map<String, dynamic>>.from(rawData));
        } else if (rawData is Map) {
          setState(() => _items = [Map<String, dynamic>.from(rawData)]);
        }
      } else {
        setState(() => _error = data['mensagem']?.toString());
      }
    } catch (e) {
      setState(() => _error = 'Erro ao carregar dados: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadData)
              : _items.isEmpty
                  ? const EmptyState(
                      icon: Icons.construction,
                      message: 'Nenhum item encontrado.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.construction, color: AppTheme.primary),
                            title: Text(item.values.first?.toString() ?? ''),
                            subtitle: Text(item.toString().substring(0, 60.clamp(0, item.toString().length))),
                          ),
                        );
                      },
                    ),
    );
  }
}
