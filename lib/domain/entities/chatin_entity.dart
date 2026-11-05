/// Entidades do Chat-In (comunicador interno do condomínio).
///
/// Privacidade: a API só devolve nome e unidade/função das pessoas —
/// nunca CPF, telefone ou e-mail.
int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
bool _bool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
DateTime? _data(dynamic v) {
  final s = v?.toString() ?? '';
  return s.isEmpty ? null : DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

class ChatInPessoa {
  final String tipo; // MORADOR | USUARIO | SISTEMA
  final int id;
  final String nome;
  final String subtitulo;
  final bool online;
  final bool ativo;
  final bool bloqueadoPorMim;

  const ChatInPessoa({
    required this.tipo,
    required this.id,
    required this.nome,
    this.subtitulo = '',
    this.online = false,
    this.ativo = true,
    this.bloqueadoPorMim = false,
  });

  factory ChatInPessoa.fromJson(Map<String, dynamic> j) => ChatInPessoa(
        tipo: j['tipo']?.toString() ?? '',
        id: _int(j['id']),
        nome: j['nome']?.toString() ?? '',
        subtitulo: j['subtitulo']?.toString() ?? '',
        online: _bool(j['online']),
        ativo: j['ativo'] == null ? true : _bool(j['ativo']),
        bloqueadoPorMim: _bool(j['bloqueado_por_mim']),
      );

  ChatInPessoa copyWith({bool? online, bool? bloqueadoPorMim}) => ChatInPessoa(
        tipo: tipo,
        id: id,
        nome: nome,
        subtitulo: subtitulo,
        online: online ?? this.online,
        ativo: ativo,
        bloqueadoPorMim: bloqueadoPorMim ?? this.bloqueadoPorMim,
      );

  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final a = partes.first[0];
    final b = partes.length > 1 ? partes.last[0] : '';
    return (a + b).toUpperCase();
  }
}

class ChatInConversa {
  final int id;
  final String tipo; // DIRETA | AVISOS
  final String titulo;
  final String subtitulo;
  final ChatInPessoa? contato;
  final bool somenteLeitura;
  final int naoLidas;
  final String? ultimaPrevia;
  final bool ultimaMinha;
  final DateTime? ultimaEm;

  const ChatInConversa({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.subtitulo = '',
    this.contato,
    this.somenteLeitura = false,
    this.naoLidas = 0,
    this.ultimaPrevia,
    this.ultimaMinha = false,
    this.ultimaEm,
  });

  bool get avisos => tipo == 'AVISOS';

  factory ChatInConversa.fromJson(Map<String, dynamic> j) {
    final ult = j['ultima'] is Map ? Map<String, dynamic>.from(j['ultima']) : null;
    return ChatInConversa(
      id: _int(j['id']),
      tipo: j['tipo']?.toString() ?? 'DIRETA',
      titulo: j['titulo']?.toString() ?? '',
      subtitulo: j['subtitulo']?.toString() ?? '',
      contato: j['contato'] is Map ? ChatInPessoa.fromJson(Map<String, dynamic>.from(j['contato'])) : null,
      somenteLeitura: _bool(j['somente_leitura']),
      naoLidas: _int(j['nao_lidas']),
      ultimaPrevia: ult?['corpo']?.toString(),
      ultimaMinha: _bool(ult?['minha']),
      ultimaEm: _data(ult?['em']),
    );
  }
}

class ChatInMensagem {
  /// Id do servidor; mensagens locais ainda não confirmadas usam [chaveLocal].
  final int id;
  final String? chaveLocal;
  final String tipo; // TEXTO | AVISO
  final bool minha;
  final String remetenteNome;
  final String? titulo;
  final String corpo;
  final DateTime criadoEm;
  final bool pendente;
  final bool falhou;

  const ChatInMensagem({
    required this.id,
    required this.tipo,
    required this.minha,
    required this.remetenteNome,
    required this.corpo,
    required this.criadoEm,
    this.titulo,
    this.chaveLocal,
    this.pendente = false,
    this.falhou = false,
  });

  bool get aviso => tipo == 'AVISO';

  factory ChatInMensagem.fromJson(Map<String, dynamic> j) {
    final rem = j['remetente'] is Map ? Map<String, dynamic>.from(j['remetente']) : const <String, dynamic>{};
    return ChatInMensagem(
      id: _int(j['id']),
      tipo: j['tipo']?.toString() ?? 'TEXTO',
      minha: _bool(j['minha']),
      remetenteNome: rem['nome']?.toString() ?? '',
      titulo: (j['titulo']?.toString().isNotEmpty ?? false) ? j['titulo'].toString() : null,
      corpo: j['corpo']?.toString() ?? '',
      criadoEm: _data(j['criado_em']) ?? DateTime.now(),
    );
  }

  ChatInMensagem copyWith({bool? pendente, bool? falhou}) => ChatInMensagem(
        id: id,
        chaveLocal: chaveLocal,
        tipo: tipo,
        minha: minha,
        remetenteNome: remetenteNome,
        titulo: titulo,
        corpo: corpo,
        criadoEm: criadoEm,
        pendente: pendente ?? this.pendente,
        falhou: falhou ?? this.falhou,
      );
}

class ChatInSync {
  final String versao;
  final int totalNaoLidas;
  final List<ChatInConversa>? conversas; // null quando a lista não mudou
  final List<ChatInMensagem> mensagens;
  final bool? contatoOnline;

  const ChatInSync({
    required this.versao,
    required this.totalNaoLidas,
    this.conversas,
    this.mensagens = const [],
    this.contatoOnline,
  });
}

class ChatInAbertura {
  final ChatInConversa conversa;
  final List<ChatInMensagem> mensagens;
  const ChatInAbertura(this.conversa, this.mensagens);
}

class ChatInPreferencias {
  final bool visivelBusca;
  final bool mostrarOnline;
  final bool notificarPush;
  const ChatInPreferencias({this.visivelBusca = true, this.mostrarOnline = true, this.notificarPush = true});

  factory ChatInPreferencias.fromJson(Map<String, dynamic> j) => ChatInPreferencias(
        visivelBusca: j['visivel_busca'] == null ? true : _bool(j['visivel_busca']),
        mostrarOnline: j['mostrar_online'] == null ? true : _bool(j['mostrar_online']),
        notificarPush: j['notificar_push'] == null ? true : _bool(j['notificar_push']),
      );
}
