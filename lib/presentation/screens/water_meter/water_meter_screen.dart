import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class WaterMeterScreen extends ConsumerStatefulWidget {
  const WaterMeterScreen({super.key});

  @override
  ConsumerState<WaterMeterScreen> createState() => _WaterMeterScreenState();
}

class _WaterMeterScreenState extends ConsumerState<WaterMeterScreen> {
  Map<String, dynamic>? _hydrometro;
  List<Map<String, dynamic>> _readings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.get(AppConstants.endpointHidrometro);
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] == true && data['dados'] != null) {
        final dados = data['dados'] as Map<String, dynamic>;
        setState(() {
          _hydrometro = dados['hidrometro'] as Map<String, dynamic>?;
          _readings = List<Map<String, dynamic>>.from(dados['leituras'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('[WaterMeterScreen] Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dados do hidrômetro
                  if (_hydrometro != null)
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
                                  child: const Icon(Icons.speed, color: AppTheme.primary),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Dados do Hidrômetro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('Medidor ativo da sua unidade', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _InfoRow(label: 'Número', value: _hydrometro!['numero_hidrometro']?.toString() ?? '—'),
                            _InfoRow(label: 'Lacre', value: _hydrometro!['numero_lacre']?.toString() ?? '—'),
                            _InfoRow(label: 'Instalação', value: _hydrometro!['data_instalacao']?.toString() ?? '—'),
                            _InfoRow(
                              label: 'Status',
                              value: _hydrometro!['ativo'] == 1 ? 'Ativo' : 'Inativo',
                              valueColor: _hydrometro!['ativo'] == 1 ? AppTheme.success : AppTheme.danger,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const EmptyState(
                      icon: Icons.water_drop_outlined,
                      message: 'Nenhum hidrômetro encontrado para sua unidade.',
                    ),

                  if (_readings.isNotEmpty) ...[
                    const SizedBox(height: 12),

                    // Gráfico de consumo
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bar_chart, color: AppTheme.primary),
                                SizedBox(width: 10),
                                Text('Consumo Mensal (m³)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: _readings
                                          .map((r) => double.tryParse(r['consumo']?.toString() ?? '0') ?? 0)
                                          .reduce((a, b) => a > b ? a : b) *
                                      1.3,
                                  barGroups: _readings.reversed
                                      .take(6)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((e) => BarChartGroupData(
                                            x: e.key,
                                            barRods: [
                                              BarChartRodData(
                                                toY: double.tryParse(e.value['consumo']?.toString() ?? '0') ?? 0,
                                                color: AppTheme.primary,
                                                width: 20,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ],
                                          ))
                                      .toList(),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, _) {
                                          final readings = _readings.reversed.take(6).toList();
                                          final idx = value.toInt();
                                          if (idx < readings.length) {
                                            final date = readings[idx]['data_leitura']?.toString() ?? '';
                                            return Text(
                                              date.length >= 7 ? date.substring(5, 7) : '',
                                              style: const TextStyle(fontSize: 10),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, _) => Text(
                                          value.toStringAsFixed(0),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  gridData: const FlGridData(show: true),
                                  borderData: FlBorderData(show: false),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Histórico de leituras
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.history, color: AppTheme.primary),
                                SizedBox(width: 10),
                                Text('Histórico de Leituras', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(AppTheme.primaryLight),
                                columns: const [
                                  DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Anterior', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Atual', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Consumo', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Valor', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _readings
                                    .map((r) => DataRow(cells: [
                                          DataCell(Text(r['data_leitura']?.toString().substring(0, 10) ?? '—')),
                                          DataCell(Text('${r['leitura_anterior'] ?? '—'} m³')),
                                          DataCell(Text('${r['leitura_atual'] ?? '—'} m³')),
                                          DataCell(Text('${r['consumo'] ?? '—'} m³')),
                                          DataCell(Text('R\$ ${r['valor_total'] ?? '—'}')),
                                        ]))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
