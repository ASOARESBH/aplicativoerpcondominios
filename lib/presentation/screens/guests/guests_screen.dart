import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../data/datasources/remote/guests_remote_datasource.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

final guestsDataSourceProvider = Provider<GuestsRemoteDataSource>(
  (ref) => GuestsRemoteDataSource(ref.read(dioClientProvider)),
);

const _tipoLabels = {
  'VISITANTE': 'Visitante',
  'PRESTADOR': 'Prestador',
  'ENTREGADOR_AUTORIZADO': 'Entregador autorizado',
  'FAMILIAR': 'Familiar',
};

const _origemLabels = {
  'APP_MORADOR': 'Aplicativo',
  'PORTAL_MORADOR': 'Portal do morador',
  'EMAIL': 'Portaria (e-mail)',
  'WHATSAPP': 'Portaria (WhatsApp)',
  'PRESENCIAL': 'Portaria (presencial)',
  'ADMINISTRATIVO': 'Administração',
};

String _mensagemErro(Object e) => e is AppException ? e.message : 'Não foi possível concluir a operação.';

String _data(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
}

String _dataHora(String valor) {
  final d = DateTime.tryParse(valor.replaceFirst(' ', 'T'));
  return d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d);
}

String _isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

({String label, Color color}) _status(String status) {
  switch (status) {
    case 'PREVISTO':
      return (label: 'Previsto', color: AppTheme.primary);
    case 'PRESENTE':
      return (label: 'No condomínio', color: AppTheme.success);
    case 'CANCELADO':
      return (label: 'Cancelado', color: AppTheme.danger);
    case 'EXPIRADO':
      return (label: 'Expirado', color: AppTheme.warning);
    case 'FINALIZADO':
      return (label: 'Finalizado', color: Colors.blueGrey);
    default:
      return (label: status, color: Colors.blueGrey);
  }
}

bool _cpfValido(String valor) {
  final c = valor.replaceAll(RegExp(r'\D'), '');
  if (c.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(c)) return false;
  for (var t = 9; t < 11; t++) {
    var soma = 0;
    for (var i = 0; i < t; i++) {
      soma += int.parse(c[i]) * (t + 1 - i);
    }
    final dv = ((soma * 10) % 11) % 10;
    if (int.parse(c[t]) != dv) return false;
  }
  return true;
}

/// CONVIDADOS — pré-cadastro do morador.
///
/// O convite cai na Lista de Convidados da portaria (Registro > Convidados),
/// com origem automática "Aplicativo" e autoria do morador logado.
class GuestsScreen extends ConsumerStatefulWidget {
  const GuestsScreen({super.key});

  @override
  ConsumerState<GuestsScreen> createState() => _GuestsScreenState();
}

class _GuestsScreenState extends ConsumerState<GuestsScreen> {
  String _filtro = 'ativos';
  List<GuestEntity> _convidados = [];
  int _ativos = 0;
  int _historico = 0;
  int _pagina = 1;
  int _totalPaginas = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _erro;
  GuestFormOptions? _opcoes;

  GuestsRemoteDataSource get _api => ref.read(guestsDataSourceProvider);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar({bool maisPaginas = false}) async {
    if (maisPaginas) {
      if (_loadingMore || _pagina >= _totalPaginas) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _erro = null;
      });
    }
    try {
      final pagina = maisPaginas ? _pagina + 1 : 1;
      final r = await _api.listar(filtro: _filtro, pagina: pagina);
      if (!mounted) return;
      setState(() {
        _convidados = maisPaginas ? [..._convidados, ...r.convidados] : r.convidados;
        _ativos = r.ativos;
        _historico = r.historico;
        _pagina = r.pagina;
        _totalPaginas = r.totalPaginas;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = _mensagemErro(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _snack(String msg, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: erro ? AppTheme.danger : AppTheme.success),
    );
  }

  Future<void> _abrirFormulario({GuestEntity? convidado}) async {
    try {
      _opcoes ??= await _api.opcoes();
      GuestEntity? completo;
      if (convidado != null) completo = await _api.obter(convidado.id);
      if (!mounted) return;
      final salvo = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _GuestFormSheet(api: _api, opcoes: _opcoes!, convidado: completo),
      );
      if (salvo != null) {
        _snack(salvo);
        setState(() => _filtro = 'ativos');
        _carregar();
      }
    } catch (e) {
      _snack(_mensagemErro(e), erro: true);
    }
  }

  Future<void> _cancelar(GuestEntity c) async {
    final motivoController = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar convite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A portaria deixará de liberar a entrada de ${c.nome} por este convite.'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              maxLength: 255,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Motivo *', hintText: 'Ex.: visita desmarcada'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            onPressed: () {
              final m = motivoController.text.trim();
              if (m.isEmpty) return;
              Navigator.pop(ctx, m);
            },
            child: const Text('Cancelar convite'),
          ),
        ],
      ),
    );
    motivoController.dispose();
    if (motivo == null) return;
    try {
      _snack(await _api.cancelar(c.id, motivo));
      _carregar();
    } catch (e) {
      _snack(_mensagemErro(e), erro: true);
    }
  }

  Future<void> _detalhes(GuestEntity resumo) async {
    try {
      final c = await _api.obter(resumo.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _GuestDetailSheet(convidado: c),
      );
    } catch (e) {
      _snack(_mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo convidado'),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.door_front_door_outlined, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pré-cadastre quem você espera. O convidado já aparece na Lista de Convidados da portaria, '
                      'que confere o documento e registra a entrada no período definido.',
                      style: TextStyle(fontSize: 13, color: AppTheme.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Ativos ($_ativos)'),
                  selected: _filtro == 'ativos',
                  onSelected: (_) {
                    setState(() => _filtro = 'ativos');
                    _carregar();
                  },
                ),
                ChoiceChip(
                  label: Text('Histórico ($_historico)'),
                  selected: _filtro == 'historico',
                  onSelected: (_) {
                    setState(() => _filtro = 'historico');
                    _carregar();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_erro != null)
              ErrorState(message: _erro!, onRetry: _carregar)
            else if (_convidados.isEmpty)
              EmptyState(
                icon: _filtro == 'ativos' ? Icons.how_to_reg_outlined : Icons.history,
                message: _filtro == 'ativos'
                    ? 'Nenhum convidado previsto.\nToque em "Novo convidado" para adiantar a portaria.'
                    : 'Nenhum convite no histórico.',
              )
            else ...[
              ..._convidados.map((c) => _GuestCard(
                    convidado: c,
                    onDetalhes: () => _detalhes(c),
                    onEditar: c.podeEditar ? () => _abrirFormulario(convidado: c) : null,
                    onCancelar: c.podeCancelar ? () => _cancelar(c) : null,
                  )),
              if (_pagina < _totalPaginas)
                Center(
                  child: TextButton(
                    onPressed: _loadingMore ? null : () => _carregar(maisPaginas: true),
                    child: _loadingMore
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Carregar mais'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  final GuestEntity convidado;
  final VoidCallback onDetalhes;
  final VoidCallback? onEditar;
  final VoidCallback? onCancelar;

  const _GuestCard({required this.convidado, required this.onDetalhes, this.onEditar, this.onCancelar});

  @override
  Widget build(BuildContext context) {
    final c = convidado;
    final st = _status(c.statusExibicao);
    final periodo = c.diasPermanencia > 1
        ? '${_data(c.dataPrevistaChegada)} a ${_data(c.validadeFim)}'
        : _data(c.dataPrevistaChegada);
    final autor = c.cadastroProprio
        ? 'Cadastrado por você'
        : 'Registrado pela portaria${c.cadastradoPorNome.isNotEmpty ? ' (${c.cadastradoPorNome})' : ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onDetalhes,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          '${_tipoLabels[c.tipoConvidado] ?? c.tipoConvidado} · ${c.tipoDocumento} ${c.documentoMascarado}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: st.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(st.label,
                        style: TextStyle(color: st.color, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _InfoChip(icon: Icons.event, text: periodo),
                  _InfoChip(icon: Icons.login, text: 'Entradas: ${c.entradasTexto}'),
                  if (c.anfitriaoTipo == 'DEPENDENTE')
                    _InfoChip(icon: Icons.family_restroom, text: 'Dependente: ${c.anfitriaoNome ?? ''}'),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Icon(c.cadastroProprio ? Icons.person_outline : Icons.room_service_outlined,
                      size: 15, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$autor · ${_origemLabels[c.origemCadastro] ?? c.origemCadastro}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  if (onEditar != null)
                    IconButton(
                      tooltip: 'Editar',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEditar,
                    ),
                  if (onCancelar != null)
                    IconButton(
                      tooltip: 'Cancelar convite',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.block, color: AppTheme.danger),
                      onPressed: onCancelar,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _GuestDetailSheet extends StatelessWidget {
  final GuestEntity convidado;
  const _GuestDetailSheet({required this.convidado});

  @override
  Widget build(BuildContext context) {
    final c = convidado;
    final st = _status(c.statusExibicao);
    Widget linha(String rotulo, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 140, child: Text(rotulo, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
              Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w500))),
            ],
          ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(st.label, style: TextStyle(color: st.color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          linha('Tipo', _tipoLabels[c.tipoConvidado] ?? c.tipoConvidado),
          linha('Documento', '${c.tipoDocumento} ${c.documentoMascarado}'),
          linha('Chegada prevista', _data(c.dataPrevistaChegada)),
          linha('Válido até', _data(c.validadeFim)),
          linha('Entradas', c.entradasTexto),
          linha('Origem', _origemLabels[c.origemCadastro] ?? c.origemCadastro),
          linha('Cadastrado em', _dataHora(c.criadoEm)),
          if (c.observacao != null) linha('Observação', c.observacao!),
          if (c.motivoCancelamento != null && c.motivoCancelamento!.isNotEmpty)
            linha('Motivo do cancelamento', c.motivoCancelamento!),
          const SizedBox(height: 16),
          const Text('Entradas e saídas na portaria', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (c.movimentacoes.isEmpty)
            Text('Nenhuma movimentação registrada ainda.', style: TextStyle(color: Colors.grey[600]))
          else
            ...c.movimentacoes.map((m) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(m.tipoAcesso.startsWith('Sa') ? Icons.logout : Icons.login, color: AppTheme.primary),
                  title: Text(m.tipoAcesso),
                  trailing: Text(_dataHora(m.dataHora)),
                )),
        ],
      ),
    );
  }
}

/// Formulário de pré-cadastro/edição. Retorna a mensagem de sucesso ao fechar.
class _GuestFormSheet extends StatefulWidget {
  final GuestsRemoteDataSource api;
  final GuestFormOptions opcoes;
  final GuestEntity? convidado;

  const _GuestFormSheet({required this.api, required this.opcoes, this.convidado});

  @override
  State<_GuestFormSheet> createState() => _GuestFormSheetState();
}

class _GuestFormSheetState extends State<_GuestFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _documentoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _diasController = TextEditingController(text: '1');
  final _obsController = TextEditingController();
  String _anfitriao = 'MORADOR';
  String? _dependenteId;
  String? _visitanteId;
  String _tipo = 'VISITANTE';
  String _tipoDocumento = 'CPF';
  late String _entradaKey;
  DateTime _chegada = DateTime.now();
  bool _salvando = false;
  String? _erro;
  String? _idempotencyKey;

  // Busca do documento em Visitantes.
  Timer? _buscaTimer;
  int _buscaToken = 0;
  String _ultimaBusca = '';
  int? _docVisitanteId;
  bool _buscandoDoc = false;
  ({String tipo, String texto})? _docStatus; // tipo: found | notfound | error

  bool get _editando => widget.convidado != null;

  @override
  void initState() {
    super.initState();
    final op = widget.opcoes;
    _entradaKey = op.modalidades.isNotEmpty ? op.modalidades.first.key : 'UNICO|1';
    if (op.tipos.isNotEmpty) _tipo = op.tipos.first.value;
    final c = widget.convidado;
    if (c != null) {
      _anfitriao = c.anfitriaoTipo == 'DEPENDENTE' ? 'DEPENDENTE' : 'MORADOR';
      _dependenteId = c.dependenteId?.toString();
      _tipo = c.tipoConvidado;
      _tipoDocumento = c.tipoDocumento == 'RG' ? 'RG' : 'CPF';
      _documentoController.text = c.documento ?? '';
      _nomeController.text = c.nome;
      _diasController.text = c.diasPermanencia.toString();
      _obsController.text = c.observacao ?? '';
      _chegada = DateTime.tryParse(c.dataPrevistaChegada) ?? DateTime.now();
      if (c.visitanteId != null) {
        _docVisitanteId = c.visitanteId;
        _ultimaBusca = '$_tipoDocumento:${_normalizar(c.documento ?? '')}';
        _docStatus = (tipo: 'found', texto: 'Vinculado ao cadastro de visitante ${c.nome}.');
      }
      final key = '${c.modalidadeEntradas}|${c.limiteEntradas ?? ''}';
      if (op.modalidades.any((m) => m.key == key)) _entradaKey = key;
    }
  }

  @override
  void dispose() {
    _buscaTimer?.cancel();
    _documentoController.dispose();
    _nomeController.dispose();
    _diasController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  int get _dias => int.tryParse(_diasController.text) ?? 0;

  String get _validadeTexto {
    if (_dias < 1) return 'Informe os dias de permanência.';
    final fim = _chegada.add(Duration(days: _dias - 1));
    return _dias == 1
        ? 'Válido somente em ${DateFormat('dd/MM/yyyy').format(_chegada)}'
        : 'Válido de ${DateFormat('dd/MM/yyyy').format(_chegada)} até ${DateFormat('dd/MM/yyyy').format(fim)} ($_dias dias)';
  }

  static String _normalizar(String v) => v.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

  void _resetBuscaDocumento() {
    _buscaTimer?.cancel();
    _buscaToken++;
    _ultimaBusca = '';
    final tinhaVinculo = _docVisitanteId != null;
    _docVisitanteId = null;
    _docStatus = null;
    _buscandoDoc = false;
    if (tinhaVinculo) _nomeController.clear();
  }

  /// Ao digitar: com o CPF completo busca automaticamente em Visitantes.
  void _documentoAlterado(String valor) {
    setState(_resetBuscaDocumento);
    if (_tipoDocumento != 'CPF') return; // RG: busca ao concluir a digitação
    final digitos = valor.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 11) return;
    if (!_cpfValido(digitos)) {
      setState(() => _docStatus = (tipo: 'error', texto: 'CPF inválido. Confira os números digitados.'));
      return;
    }
    _buscaTimer = Timer(const Duration(milliseconds: 300), _buscarDocumento);
  }

  Future<void> _buscarDocumento() async {
    final documento = _documentoController.text.trim();
    final chave = '$_tipoDocumento:${_normalizar(documento)}';
    if (documento.isEmpty || chave == _ultimaBusca) return;
    if (_tipoDocumento == 'CPF' && !_cpfValido(documento)) return;
    if (_tipoDocumento == 'RG' && _normalizar(documento).length < 5) return;
    _ultimaBusca = chave;
    final token = ++_buscaToken;
    setState(() => _buscandoDoc = true);
    try {
      final r = await widget.api.buscarDocumento(_tipoDocumento, documento);
      if (!mounted || token != _buscaToken) return;
      setState(() {
        if (r.encontrado) {
          _docVisitanteId = r.visitanteId;
          _nomeController.text = r.nome ?? '';
          _docStatus = (tipo: 'found', texto: 'Visitante já cadastrado: ${r.nome ?? ''}. O convite será vinculado a este cadastro.');
        } else {
          _docVisitanteId = null;
          _docStatus = (tipo: 'notfound', texto: r.mensagem);
        }
      });
    } catch (e) {
      if (!mounted || token != _buscaToken) return;
      _ultimaBusca = '';
      setState(() => _docStatus = (tipo: 'error', texto: _mensagemErro(e)));
    } finally {
      if (mounted && token == _buscaToken) setState(() => _buscandoDoc = false);
    }
  }

  Widget _docStatusWidget() {
    if (_buscandoDoc) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Buscando em Visitantes...', style: TextStyle(fontSize: 13)),
        ]),
      );
    }
    final st = _docStatus;
    if (st == null) return const SizedBox.shrink();
    final cor = st.tipo == 'found' ? AppTheme.success : (st.tipo == 'notfound' ? AppTheme.warning : AppTheme.danger);
    final icone = st.tipo == 'found'
        ? Icons.check_circle_outline
        : (st.tipo == 'notfound' ? Icons.person_add_alt_1 : Icons.error_outline);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: 8),
          Expanded(child: Text(st.texto, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Map<String, dynamic> _payload() {
    final entrada = widget.opcoes.modalidades.firstWhere(
      (m) => m.key == _entradaKey,
      orElse: () => const GuestEntryOption('UNICO', 'Acesso único', 1),
    );
    final p = <String, dynamic>{
      'anfitriao_tipo': _anfitriao,
      'dependente_id': _anfitriao == 'DEPENDENTE' ? int.tryParse(_dependenteId ?? '') : null,
      'tipo_convidado': _tipo,
      'data_prevista_chegada': _isoDate(_chegada),
      'dias_permanencia': _dias,
      'modalidade_entradas': entrada.modalidade,
      'limite_entradas': entrada.limite,
      'observacao': _obsController.text.trim(),
    };
    if (_visitanteId != null) {
      p['visitante_id'] = int.tryParse(_visitanteId!);
    } else if (_docVisitanteId != null) {
      p['visitante_id'] = _docVisitanteId;
    } else {
      p['tipo_documento'] = _tipoDocumento;
      p['documento'] = _documentoController.text.trim();
      p['nome'] = _nomeController.text.trim();
    }
    return p;
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _chegada.isBefore(inicio) ? inicio : _chegada,
      firstDate: inicio,
      lastDate: inicio.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _chegada = picked);
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    final payload = _payload();
    setState(() => _salvando = true);
    try {
      String mensagem;
      if (_editando) {
        mensagem = await widget.api.editar(widget.convidado!.id, payload);
      } else {
        // Avisa sobre alertas ativos da própria unidade antes de cadastrar.
        List<String> alertas = const [];
        try {
          alertas = await widget.api.verificarAlertas(payload);
        } on AppException catch (e) {
          // Erro de validação interrompe; indisponibilidade da verificação (5xx) não bloqueia.
          if (e.statusCode != null && e.statusCode! < 500) rethrow;
        }
        if (alertas.isNotEmpty && mounted) {
          final seguir = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Alerta ativo na sua unidade'),
              content: Text(
                '${alertas.map((t) => '• $t').join('\n')}\n\n'
                'A portaria seguirá o alerta na chegada. Deseja cadastrar mesmo assim?',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cadastrar')),
              ],
            ),
          );
          if (seguir != true) return;
        }
        _idempotencyKey ??= const Uuid().v4();
        mensagem = await widget.api.criar({...payload, 'idempotency_key': _idempotencyKey});
      }
      if (mounted) Navigator.pop(context, mensagem);
    } catch (e) {
      if (mounted) setState(() => _erro = _mensagemErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final op = widget.opcoes;
    final usandoVisitante = _visitanteId != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_editando ? 'Editar convidado' : 'Pré-cadastrar convidado',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Unidade ${op.unidade}', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              if (_erro != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_erro!, style: const TextStyle(color: AppTheme.danger)),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                value: _anfitriao,
                decoration: const InputDecoration(labelText: 'Convidado de *'),
                items: [
                  const DropdownMenuItem(value: 'MORADOR', child: Text('Mim (titular)')),
                  if (op.dependentes.isNotEmpty || _anfitriao == 'DEPENDENTE')
                    const DropdownMenuItem(value: 'DEPENDENTE', child: Text('Um dependente')),
                ],
                onChanged: (v) => setState(() {
                  _anfitriao = v ?? 'MORADOR';
                  if (_anfitriao == 'MORADOR') _dependenteId = null;
                }),
              ),
              if (_anfitriao == 'DEPENDENTE') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // Dependente desativado depois do convite não fica pré-selecionado (evita valor fora da lista).
                  value: op.dependentes.any((d) => d.value == _dependenteId) ? _dependenteId : null,
                  decoration: const InputDecoration(labelText: 'Dependente *'),
                  items: op.dependentes
                      .map((d) => DropdownMenuItem(value: d.value, child: Text(d.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _dependenteId = v),
                  validator: (v) => v == null || v.isEmpty ? 'Selecione o dependente' : null,
                ),
              ],
              if (!_editando && op.visitantes.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _visitanteId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Visitante já cadastrado'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Informar os dados manualmente')),
                    ...op.visitantes.map((v) => DropdownMenuItem<String?>(
                          value: v.value,
                          child: Text(v.label, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _visitanteId = v),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: op.tipos.any((t) => t.value == _tipo) ? _tipo : null,
                decoration: const InputDecoration(labelText: 'Tipo *'),
                items: op.tipos.map((t) => DropdownMenuItem(value: t.value, child: Text(t.label))).toList(),
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
                validator: (v) => v == null ? 'Selecione o tipo' : null,
              ),
              if (!usandoVisitante) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        value: _tipoDocumento,
                        decoration: const InputDecoration(labelText: 'Documento'),
                        items: const [
                          DropdownMenuItem(value: 'CPF', child: Text('CPF')),
                          DropdownMenuItem(value: 'RG', child: Text('RG')),
                        ],
                        onChanged: (v) => setState(() {
                          _tipoDocumento = v ?? 'CPF';
                          _documentoController.clear();
                          _resetBuscaDocumento();
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _documentoController,
                        keyboardType: _tipoDocumento == 'CPF' ? TextInputType.number : TextInputType.text,
                        inputFormatters: _tipoDocumento == 'CPF'
                            ? [CpfInputFormatter()]
                            : [LengthLimitingTextInputFormatter(20)],
                        decoration: InputDecoration(labelText: 'Número *', hintText: _tipoDocumento == 'CPF' ? '000.000.000-00' : 'Número do RG'),
                        onChanged: _documentoAlterado,
                        onEditingComplete: () {
                          _buscarDocumento();
                          FocusScope.of(context).nextFocus();
                        },
                        validator: (v) {
                          final valor = (v ?? '').trim();
                          if (valor.isEmpty) return 'Informe o documento';
                          if (_tipoDocumento == 'CPF' && !_cpfValido(valor)) return 'CPF inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                _docStatusWidget(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nomeController,
                  readOnly: _docVisitanteId != null,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Nome completo *',
                    counterText: '',
                    hintText: _docStatus?.tipo == 'notfound' ? 'Digite o nome completo do convidado' : null,
                  ),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Informe o nome completo' : null,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _escolherData,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Chegada: ${DateFormat('dd/MM/yyyy').format(_chegada)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _diasController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                      decoration: const InputDecoration(labelText: 'Dias *'),
                      onChanged: (_) => setState(() {}),
                      validator: (_) => _dias < 1 || _dias > op.diasPermanenciaMax
                          ? '1 a ${op.diasPermanenciaMax}'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_validadeTexto, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _entradaKey,
                decoration: const InputDecoration(labelText: 'Entradas permitidas *'),
                items: op.modalidades.map((m) => DropdownMenuItem(value: m.key, child: Text(m.label))).toList(),
                onChanged: (v) => setState(() => _entradaKey = v ?? _entradaKey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _obsController,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Observação para a portaria (opcional)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_editando ? Icons.save_outlined : Icons.person_add_alt_1),
                label: Text(_editando ? 'Salvar alterações' : 'Cadastrar convidado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
