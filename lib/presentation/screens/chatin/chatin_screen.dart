import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/chatin_remote_datasource.dart';
import '../../../domain/entities/chatin_entity.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_overlay.dart';

/// Fonte de dados do Chat-In (token Bearer do morador via [dioClientProvider]).
final chatinDataSourceProvider = Provider<ChatInRemoteDataSource>(
  (ref) => ChatInRemoteDataSource(ref.read(dioClientProvider)),
);

/// Total de mensagens não lidas (badge do menu). Atualizado pelas telas do
/// Chat-In e pelo ping de presença do [HomeScreen].
final chatinUnreadProvider = StateProvider<int>((ref) => 0);

const _intervaloAtivo = Duration(seconds: 5);
const _maxCaracteres = 2000;
const _listaDeEmojis = ['😀', '😂', '😊', '😍', '🙏', '👍', '👏', '🎉', '😉', '😢', '😮', '🤔', '❤️', '✅', '🚗', '📦', '🏠', '🔑', '⚠️', '👋'];

String _erro(Object e) => e is AppException ? e.message : 'Não foi possível concluir a operação.';

String _quandoCurto(DateTime? d) {
  if (d == null) return '';
  final hoje = DateTime.now();
  final dia = DateTime(d.year, d.month, d.day);
  final diff = DateTime(hoje.year, hoje.month, hoje.day).difference(dia).inDays;
  if (diff == 0) return DateFormat('HH:mm').format(d);
  if (diff == 1) return 'Ontem';
  return DateFormat('dd/MM').format(d);
}

String _rotuloDia(DateTime d) {
  final hoje = DateTime.now();
  final diff = DateTime(hoje.year, hoje.month, hoje.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  return DateFormat('dd/MM/yyyy').format(d);
}

Color _corAvatar(String chave) {
  var h = 0;
  for (final c in chave.codeUnits) {
    h = (h * 31 + c) % 360;
  }
  return HSLColor.fromAHSL(1, h.toDouble(), 0.55, 0.45).toColor();
}

class _Avatar extends StatelessWidget {
  final ChatInPessoa? pessoa;
  final bool avisos;
  final double raio;
  const _Avatar({this.pessoa, this.avisos = false, this.raio = 22});

  @override
  Widget build(BuildContext context) {
    final avatar = avisos
        ? CircleAvatar(
            radius: raio,
            backgroundColor: AppTheme.warning,
            child: Icon(Icons.campaign, color: Colors.white, size: raio),
          )
        : CircleAvatar(
            radius: raio,
            backgroundColor: _corAvatar('${pessoa?.tipo}${pessoa?.id}'),
            child: Text(pessoa?.iniciais ?? '?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: raio * 0.62)),
          );
    if (pessoa?.online != true) return avatar;
    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      Positioned(
        right: -1,
        bottom: -1,
        child: Container(
          width: raio * 0.55,
          height: raio * 0.55,
          decoration: BoxDecoration(
            color: AppTheme.success,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
// LISTA DE CONVERSAS + BUSCA DE CONTATOS
// ════════════════════════════════════════════════════════════════════
class ChatInScreen extends ConsumerStatefulWidget {
  const ChatInScreen({super.key});

  @override
  ConsumerState<ChatInScreen> createState() => _ChatInScreenState();
}

class _ChatInScreenState extends ConsumerState<ChatInScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _busca = TextEditingController();
  Timer? _timer;
  Timer? _buscaTimer;
  String _versao = '';
  List<ChatInConversa> _conversas = const [];
  List<ChatInPessoa> _contatos = const [];
  bool _carregando = true;
  bool _buscando = false;
  String? _erroLista;
  String? _erroContatos;
  /// true enquanto uma conversa está aberta por cima desta tela (ela faz o próprio sync).
  bool _pausado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && _tabs.index == 1 && _contatos.isEmpty) _buscarContatos('');
    });
    _sincronizar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _buscaTimer?.cancel();
    _tabs.dispose();
    _busca.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_pausado) _sincronizar();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  Future<void> _sincronizar() async {
    _timer?.cancel();
    if (_pausado) return;
    if (ModalRoute.of(context)?.isCurrent == false) {
      // conversa aberta por deep link (push) por cima da lista: ela já sincroniza
      _timer = Timer(const Duration(seconds: 15), _sincronizar);
      return;
    }
    try {
      final s = await ref.read(chatinDataSourceProvider).sync(versao: _versao);
      if (!mounted) return;
      ref.read(chatinUnreadProvider.notifier).state = s.totalNaoLidas;
      setState(() {
        _versao = s.versao;
        if (s.conversas != null) _conversas = s.conversas!;
        _carregando = false;
        _erroLista = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        if (_conversas.isEmpty) _erroLista = _erro(e);
      });
    } finally {
      if (mounted && !_pausado) _timer = Timer(_intervaloAtivo, _sincronizar);
    }
  }

  void _aoDigitarBusca(String q) {
    _buscaTimer?.cancel();
    _buscaTimer = Timer(const Duration(milliseconds: 350), () => _buscarContatos(q.trim()));
  }

  Future<void> _buscarContatos(String q) async {
    setState(() {
      _buscando = true;
      _erroContatos = null;
    });
    try {
      final lista = await ref.read(chatinDataSourceProvider).contatos(q);
      if (mounted) setState(() => _contatos = lista);
    } catch (e) {
      if (mounted) setState(() => _erroContatos = _erro(e));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _abrirConversa(ChatInConversa c) async {
    _timer?.cancel();
    _pausado = true;
    await context.push('/home/chatin/${c.id}', extra: c);
    _pausado = false;
    _versao = '';
    if (mounted) _sincronizar();
  }

  Future<void> _abrirContato(ChatInPessoa p) async {
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      final ab = await ref.read(chatinDataSourceProvider).abrir(p.tipo, p.id);
      if (!mounted) return;
      _tabs.animateTo(0);
      await _abrirConversa(ab.conversa);
    } catch (e) {
      mensageiro.showSnackBar(SnackBar(content: Text(_erro(e))));
    }
  }

  Future<void> _abrirPreferencias() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PreferenciasSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat-In'),
        actions: [
          IconButton(
            tooltip: 'Preferências',
            icon: const Icon(Icons.tune),
            onPressed: _abrirPreferencias,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Conversas'),
            Tab(icon: Icon(Icons.person_search_outlined), text: 'Nova conversa'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [_listaConversas(), _listaContatos()]),
    );
  }

  Widget _listaConversas() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erroLista != null) return ErrorState(message: _erroLista!, onRetry: _sincronizar);
    if (_conversas.isEmpty) {
      return EmptyState(
        icon: Icons.forum_outlined,
        message: 'Nenhuma conversa ainda.\nFale com a administração ou com seus vizinhos.',
        actionLabel: 'Nova conversa',
        onAction: () => _tabs.animateTo(1),
      );
    }
    return RefreshIndicator(
      onRefresh: () {
        _versao = '';
        return _sincronizar();
      },
      child: ListView.separated(
        itemCount: _conversas.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
        itemBuilder: (context, i) {
          final c = _conversas[i];
          final previa = '${c.ultimaMinha ? 'Você: ' : ''}${c.ultimaPrevia ?? ''}';
          return ListTile(
            leading: _Avatar(pessoa: c.contato, avisos: c.avisos),
            title: Row(children: [
              Expanded(
                child: Text(c.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: c.naoLidas > 0 ? FontWeight.w800 : FontWeight.w600)),
              ),
              Text(_quandoCurto(c.ultimaEm), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                c.subtitulo + (c.contato?.bloqueadoPorMim == true ? ' · bloqueado' : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              Row(children: [
                Expanded(
                  child: Text(previa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.naoLidas > 0 ? Colors.black87 : Colors.grey.shade600,
                          fontWeight: c.naoLidas > 0 ? FontWeight.w600 : FontWeight.normal)),
                ),
                if (c.naoLidas > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text(c.naoLidas > 99 ? '99+' : '${c.naoLidas}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ]),
            isThreeLine: true,
            onTap: () => _abrirConversa(c),
          );
        },
      ),
    );
  }

  Widget _listaContatos() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: TextField(
          controller: _busca,
          onChanged: _aoDigitarBusca,
          textInputAction: TextInputAction.search,
          maxLength: 60,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar por nome ou unidade',
            counterText: '',
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Somente nome e unidade são exibidos. Moradores podem se ocultar da busca nas preferências.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: _buscando && _contatos.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _erroContatos != null
                ? ErrorState(message: _erroContatos!, onRetry: () => _buscarContatos(_busca.text.trim()))
                : _contatos.isEmpty
                    ? const EmptyState(icon: Icons.person_off_outlined, message: 'Nenhum contato encontrado.')
                    : ListView.separated(
                        itemCount: _contatos.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                        itemBuilder: (context, i) {
                          final p = _contatos[i];
                          return ListTile(
                            leading: _Avatar(pessoa: p),
                            title: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(p.subtitulo),
                            trailing: p.online
                                ? const Text('online',
                                    style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 12))
                                : null,
                            onTap: () => _abrirContato(p),
                          );
                        },
                      ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
// PREFERÊNCIAS (privacidade e push)
// ════════════════════════════════════════════════════════════════════
class _PreferenciasSheet extends ConsumerStatefulWidget {
  const _PreferenciasSheet();

  @override
  ConsumerState<_PreferenciasSheet> createState() => _PreferenciasSheetState();
}

class _PreferenciasSheetState extends ConsumerState<_PreferenciasSheet> {
  ChatInPreferencias? _p;
  String? _erroMsg;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final p = await ref.read(chatinDataSourceProvider).preferencias();
      if (mounted) setState(() => _p = p);
    } catch (e) {
      if (mounted) setState(() => _erroMsg = _erro(e));
    }
  }

  Future<void> _salvar(String chave, bool valor) async {
    setState(() => _salvando = true);
    try {
      final p = await ref.read(chatinDataSourceProvider).salvarPreferencias({chave: valor});
      if (mounted) setState(() => _p = p);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_erro(e))));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Preferências do Chat-In', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          if (_erroMsg != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_erroMsg!, style: const TextStyle(color: AppTheme.danger)))
          else if (p == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else ...[
            SwitchListTile(
              value: p.visivelBusca,
              onChanged: _salvando ? null : (v) => _salvar('visivel_busca', v),
              title: const Text('Aparecer na busca de moradores'),
              subtitle: const Text('Desligado: outros moradores não encontram você. A administração continua podendo falar com você.'),
            ),
            SwitchListTile(
              value: p.mostrarOnline,
              onChanged: _salvando ? null : (v) => _salvar('mostrar_online', v),
              title: const Text('Mostrar quando estou online'),
            ),
            SwitchListTile(
              value: p.notificarPush,
              onChanged: _salvando ? null : (v) => _salvar('notificar_push', v),
              title: const Text('Notificações de mensagens'),
              subtitle: const Text('Receber push neste aparelho quando chegar mensagem ou aviso.'),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'O Chat-In mostra apenas seu nome e unidade. Você pode bloquear qualquer contato pelo menu da conversa.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// CONVERSA
// ════════════════════════════════════════════════════════════════════
class ChatInConversationScreen extends ConsumerStatefulWidget {
  final int conversaId;
  final ChatInConversa? conversaInicial;
  const ChatInConversationScreen({super.key, required this.conversaId, this.conversaInicial});

  @override
  ConsumerState<ChatInConversationScreen> createState() => _ChatInConversationScreenState();
}

class _ChatInConversationScreenState extends ConsumerState<ChatInConversationScreen> with WidgetsBindingObserver {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  final _uuid = const Uuid();
  ChatInConversa? _conversa;
  List<ChatInMensagem> _mensagens = [];
  int _ultimoId = 0;
  bool _temMais = false;
  bool _carregando = true;
  bool _carregandoMais = false;
  bool _emojis = false;
  bool _emPrimeiroPlano = true;
  String? _erroMsg;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.conversaChatinAberta = widget.conversaId;
    _conversa = widget.conversaInicial;
    _scroll.addListener(_aoRolar);
    _carregar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (NotificationService.conversaChatinAberta == widget.conversaId) {
      NotificationService.conversaChatinAberta = null;
    }
    _timer?.cancel();
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _emPrimeiroPlano = state == AppLifecycleState.resumed;
    NotificationService.conversaChatinAberta = _emPrimeiroPlano ? widget.conversaId : null;
    if (_emPrimeiroPlano) {
      _sincronizar();
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _carregar() async {
    final ds = ref.read(chatinDataSourceProvider);
    try {
      if (_conversa == null) {
        final lista = await ds.conversas();
        _conversa = lista.where((c) => c.id == widget.conversaId).firstOrNull;
        if (_conversa == null) throw const AppException('Conversa não encontrada ou arquivada.');
      }
      final r = await ds.mensagens(widget.conversaId);
      if (!mounted) return;
      setState(() {
        _mensagens = List.of(r.mensagens);
        _temMais = r.temMais;
        _ultimoId = _maiorId();
        _carregando = false;
      });
      _rolarFim(animar: false);
      _sincronizar();
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erroMsg = _erro(e);
        });
      }
    }
  }

  int _maiorId() => _mensagens.fold<int>(0, (m, x) => x.chaveLocal == null && x.id > m ? x.id : m);

  Future<void> _sincronizar() async {
    _timer?.cancel();
    if (!_emPrimeiroPlano) return;
    try {
      final s = await ref.read(chatinDataSourceProvider).sync(
            conversaId: widget.conversaId,
            aposId: _ultimoId,
            marcarLida: true,
          );
      if (!mounted) return;
      ref.read(chatinUnreadProvider.notifier).state = s.totalNaoLidas;
      final noFim = !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.offset < 80;
      setState(() {
        _anexar(s.mensagens);
        if (s.contatoOnline != null && _conversa?.contato != null && _conversa!.contato!.online != s.contatoOnline) {
          _conversa = ChatInConversa(
            id: _conversa!.id,
            tipo: _conversa!.tipo,
            titulo: _conversa!.titulo,
            subtitulo: _conversa!.subtitulo,
            contato: _conversa!.contato!.copyWith(online: s.contatoOnline),
            somenteLeitura: _conversa!.somenteLeitura,
          );
        }
      });
      if (s.mensagens.isNotEmpty && noFim) _rolarFim();
    } catch (e) {
      debugPrint('[Chat-In] sync falhou: $e');
    } finally {
      if (mounted && _emPrimeiroPlano) _timer = Timer(_intervaloAtivo, _sincronizar);
    }
  }

  void _anexar(List<ChatInMensagem> novas) {
    final ids = _mensagens.where((m) => m.chaveLocal == null).map((m) => m.id).toSet();
    for (final m in novas) {
      if (!ids.contains(m.id)) _mensagens.add(m);
    }
    _ultimoId = _maiorId();
  }

  void _aoRolar() {
    if (_scroll.hasClients && _scroll.offset < 40 && _temMais && !_carregandoMais) _carregarAnteriores();
  }

  Future<void> _carregarAnteriores() async {
    final primeiro = _mensagens.where((m) => m.chaveLocal == null).firstOrNull;
    if (primeiro == null) return;
    _carregandoMais = true;
    try {
      final antes = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
      final r = await ref.read(chatinDataSourceProvider).mensagens(widget.conversaId, antesId: primeiro.id);
      if (!mounted) return;
      setState(() {
        _mensagens = [...r.mensagens, ..._mensagens];
        _temMais = r.temMais;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent - antes);
      });
    } catch (_) {
      // mantém o histórico atual; nova tentativa ao rolar de novo
    } finally {
      _carregandoMais = false;
    }
  }

  void _rolarFim({bool animar = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final alvo = _scroll.position.maxScrollExtent;
      animar
          ? _scroll.animateTo(alvo, duration: const Duration(milliseconds: 200), curve: Curves.easeOut)
          : _scroll.jumpTo(alvo);
    });
  }

  Future<void> _enviar({ChatInMensagem? reenviar}) async {
    final texto = (reenviar?.corpo ?? _texto.text).trim();
    if (texto.isEmpty) return;
    if (texto.length > _maxCaracteres) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('A mensagem pode ter até $_maxCaracteres caracteres.')));
      return;
    }
    final chave = reenviar?.chaveLocal ?? _uuid.v4();
    final local = ChatInMensagem(
      id: 0,
      chaveLocal: chave,
      tipo: 'TEXTO',
      minha: true,
      remetenteNome: 'Você',
      corpo: texto,
      criadoEm: DateTime.now(),
      pendente: true,
    );
    setState(() {
      if (reenviar != null) {
        _mensagens = _mensagens.map((m) => m.chaveLocal == chave ? local : m).toList();
      } else {
        _mensagens.add(local);
        _texto.clear();
        _emojis = false;
      }
    });
    _rolarFim();
    try {
      final real = await ref.read(chatinDataSourceProvider).enviar(widget.conversaId, texto, chave);
      if (!mounted) return;
      setState(() {
        final jaVeio = _mensagens.any((m) => m.chaveLocal == null && m.id == real.id);
        _mensagens = jaVeio
            ? _mensagens.where((m) => m.chaveLocal != chave).toList()
            : _mensagens.map((m) => m.chaveLocal == chave ? real : m).toList();
        _ultimoId = _maiorId();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensagens = _mensagens.map((m) => m.chaveLocal == chave ? m.copyWith(pendente: false, falhou: true) : m).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_erro(e))));
    }
  }

  void _inserirEmoji(String emoji) {
    final sel = _texto.selection;
    final ini = sel.isValid ? sel.start : _texto.text.length;
    final fim = sel.isValid ? sel.end : _texto.text.length;
    final novo = _texto.text.replaceRange(ini, fim, emoji);
    _texto.value = TextEditingValue(text: novo, selection: TextSelection.collapsed(offset: ini + emoji.length));
  }

  Future<void> _alternarBloqueio() async {
    final contato = _conversa?.contato;
    if (contato == null) return;
    final bloquear = !contato.bloqueadoPorMim;
    if (bloquear) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Bloquear ${contato.nome}?'),
          content: const Text('Vocês não poderão trocar mensagens e essa pessoa deixará de ver você na busca.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bloquear'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ref.read(chatinDataSourceProvider).bloquear(contato.tipo, contato.id, bloquear: bloquear);
      if (!mounted) return;
      setState(() {
        _conversa = ChatInConversa(
          id: _conversa!.id,
          tipo: _conversa!.tipo,
          titulo: _conversa!.titulo,
          subtitulo: _conversa!.subtitulo,
          contato: contato.copyWith(bloqueadoPorMim: bloquear),
          somenteLeitura: _conversa!.somenteLeitura,
        );
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_erro(e))));
    }
  }

  Future<void> _arquivar() async {
    try {
      await ref.read(chatinDataSourceProvider).arquivar(widget.conversaId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_erro(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _conversa;
    final contato = c?.contato;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: c == null
            ? const Text('Chat-In')
            : Row(children: [
                _Avatar(pessoa: contato, avisos: c.avisos, raio: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(c.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                    Text(
                      contato?.online == true ? 'online · ${c.subtitulo}' : c.subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ]),
                ),
              ]),
        actions: [
          if (c != null && !c.avisos && contato != null)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'bloquear' ? _alternarBloqueio() : _arquivar(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'bloquear',
                  child: Text(contato.bloqueadoPorMim ? 'Desbloquear contato' : 'Bloquear contato'),
                ),
                const PopupMenuItem(value: 'arquivar', child: Text('Arquivar conversa')),
              ],
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erroMsg != null
              ? ErrorState(
                  message: _erroMsg!,
                  onRetry: () {
                    setState(() {
                      _erroMsg = null;
                      _carregando = true;
                    });
                    _carregar();
                  })
              : Column(children: [
                  Expanded(child: _listaMensagens()),
                  _rodape(),
                ]),
    );
  }

  Widget _listaMensagens() {
    if (_mensagens.isEmpty) {
      return EmptyState(
        icon: Icons.send_outlined,
        message: _conversa?.somenteLeitura == true
            ? 'Nenhum aviso por enquanto.'
            : 'Diga olá! As mensagens ficam guardadas no histórico.',
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      itemCount: _mensagens.length + (_temMais ? 1 : 0),
      itemBuilder: (context, i) {
        if (_temMais && i == 0) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final idx = _temMais ? i - 1 : i;
        final m = _mensagens[idx];
        final anterior = idx > 0 ? _mensagens[idx - 1] : null;
        final novoDia = anterior == null || _rotuloDia(anterior.criadoEm) != _rotuloDia(m.criadoEm);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (novoDia)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                child: Text(_rotuloDia(m.criadoEm), style: const TextStyle(fontSize: 11)),
              ),
            ),
          m.aviso ? _aviso(m) : _balao(m),
        ]);
      },
    );
  }

  Widget _aviso(ChatInMensagem m) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          border: Border.all(color: const Color(0xFFFDE68A)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.campaign, size: 16, color: Color(0xFFB45309)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(m.remetenteNome.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
            ),
            Text(DateFormat('HH:mm').format(m.criadoEm), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          if (m.titulo != null) ...[
            const SizedBox(height: 4),
            Text(m.titulo!, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 4),
          SelectableText(m.corpo, style: const TextStyle(fontSize: 14, height: 1.4)),
        ]),
      );

  Widget _balao(ChatInMensagem m) {
    final minha = m.minha;
    return Align(
      alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: m.falhou ? () => _enviar(reenviar: m) : null,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 5),
          decoration: BoxDecoration(
            color: m.falhou ? const Color(0xFFFEF2F2) : (minha ? const Color(0xFFDBEAFE) : Colors.white),
            border: Border.all(color: m.falhou ? const Color(0xFFFCA5A5) : Colors.grey.shade200),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(minha ? 14 : 4),
              bottomRight: Radius.circular(minha ? 4 : 14),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(m.corpo, style: const TextStyle(fontSize: 15, height: 1.35)),
            ),
            const SizedBox(height: 2),
            m.falhou
                ? const Text('Não enviada · toque para reenviar', style: TextStyle(fontSize: 10, color: AppTheme.danger))
                : m.pendente
                    ? const Icon(Icons.schedule, size: 12, color: Colors.grey)
                    : Text(DateFormat('HH:mm').format(m.criadoEm), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Widget _rodape() {
    final c = _conversa;
    if (c == null) return const SizedBox.shrink();
    String? aviso;
    if (c.somenteLeitura) {
      aviso = 'Canal de avisos da portaria e administração — somente leitura.';
    } else if (c.contato?.ativo == false) {
      aviso = 'Este contato não está mais disponível.';
    } else if (c.contato?.bloqueadoPorMim == true) {
      aviso = 'Você bloqueou este contato. Desbloqueie pelo menu para enviar mensagens.';
    }
    if (aviso != null) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          color: Colors.white,
          child: Text(aviso, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_emojis) Wrap(children: _listaEmojis()),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(
              tooltip: 'Emojis',
              icon: Icon(_emojis ? Icons.keyboard : Icons.emoji_emotions_outlined),
              onPressed: () => setState(() => _emojis = !_emojis),
            ),
            Expanded(
              child: TextField(
                controller: _texto,
                minLines: 1,
                maxLines: 5,
                maxLength: _maxCaracteres,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Escreva uma mensagem…',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Enviar',
              icon: const Icon(Icons.send),
              onPressed: () => _enviar(),
            ),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _listaEmojis() => _listaDeEmojis
      .map((e) => InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _inserirEmoji(e),
            child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 24))),
          ))
      .toList();
}
