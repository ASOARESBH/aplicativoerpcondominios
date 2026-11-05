import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/chatin_entity.dart';

/// Acesso à API do Chat-In (`api/api_chatin.php`).
///
/// A identidade (morador) e o condomínio vêm do token Bearer — o app nunca
/// informa quem é. `plataforma=app` permite ao servidor não enviar push
/// enquanto a conversa está aberta na tela.
class ChatInRemoteDataSource {
  final DioClient _client;
  ChatInRemoteDataSource(this._client);

  Future<Map<String, dynamic>> _call(
    String acao, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    try {
      final params = <String, dynamic>{'acao': acao, ...?query};
      final Response response = method == 'GET'
          ? await _client.dio.get(AppConstants.endpointChatin, queryParameters: params)
          : await _client.dio.post(AppConstants.endpointChatin, queryParameters: params, data: body ?? {});
      final data = response.data;
      if (data is! Map) throw const AppException('Resposta inválida do servidor.');
      final map = Map<String, dynamic>.from(data);
      if (response.statusCode == 401) throw const UnauthorizedException();
      if (map['sucesso'] != true) {
        throw AppException(map['mensagem']?.toString() ?? 'Não foi possível concluir a operação.',
            statusCode: response.statusCode);
      }
      final dados = map['dados'];
      return dados is Map ? Map<String, dynamic>.from(dados) : <String, dynamic>{};
    } on DioException catch (e) {
      final erro = e.error;
      if (erro is AppException) throw erro;
      throw AppException(e.message ?? 'Erro de comunicação com o servidor.');
    }
  }

  List<ChatInMensagem> _mensagens(dynamic v) => v is List
      ? v.whereType<Map>().map((m) => ChatInMensagem.fromJson(Map<String, dynamic>.from(m))).toList()
      : const [];

  List<ChatInConversa> _conversas(dynamic v) => v is List
      ? v.whereType<Map>().map((c) => ChatInConversa.fromJson(Map<String, dynamic>.from(c))).toList()
      : const [];

  /// Presença + não lidas; lista de conversas se [versao] mudou;
  /// mensagens novas da conversa aberta (após [aposId]).
  Future<ChatInSync> sync({String versao = '', int? conversaId, int aposId = 0, bool marcarLida = false}) async {
    final d = await _call('sync', query: {
      'plataforma': 'app',
      'versao': versao,
      if (conversaId != null) 'conversa_id': conversaId,
      if (conversaId != null) 'apos_id': aposId,
      if (conversaId != null && marcarLida) 'marcar_lida': 1,
    });
    return ChatInSync(
      versao: d['versao']?.toString() ?? '',
      totalNaoLidas: int.tryParse(d['total_nao_lidas']?.toString() ?? '') ?? 0,
      conversas: d.containsKey('conversas') ? _conversas(d['conversas']) : null,
      mensagens: _mensagens(d['mensagens']),
      contatoOnline: d['contato_online'] is bool ? d['contato_online'] as bool : null,
    );
  }

  Future<List<ChatInConversa>> conversas() async => _conversas((await _call('conversas'))['conversas']);

  Future<List<ChatInPessoa>> contatos(String q) async {
    final lista = (await _call('contatos', query: {'q': q}))['contatos'];
    return lista is List
        ? lista.whereType<Map>().map((p) => ChatInPessoa.fromJson(Map<String, dynamic>.from(p))).toList()
        : const [];
  }

  Future<({List<ChatInMensagem> mensagens, bool temMais})> mensagens(int conversaId, {int antesId = 0, int limite = 40}) async {
    final d = await _call('mensagens', query: {'conversa_id': conversaId, 'antes_id': antesId, 'limite': limite});
    return (mensagens: _mensagens(d['mensagens']), temMais: d['tem_mais'] == true);
  }

  Future<ChatInAbertura> abrir(String tipo, int id) async {
    final d = await _call('abrir', method: 'POST', body: {'tipo': tipo, 'id': id});
    final conv = d['conversa'] is Map ? Map<String, dynamic>.from(d['conversa']) : <String, dynamic>{};
    return ChatInAbertura(ChatInConversa.fromJson(conv), _mensagens(d['mensagens']));
  }

  Future<ChatInMensagem> enviar(int conversaId, String corpo, String idempotencyKey) async {
    final d = await _call('enviar', method: 'POST', body: {
      'conversa_id': conversaId,
      'corpo': corpo,
      'idempotency_key': idempotencyKey,
    });
    return ChatInMensagem.fromJson(Map<String, dynamic>.from(d['mensagem'] as Map));
  }

  Future<void> marcarLida(int conversaId) => _call('lida', method: 'POST', body: {'conversa_id': conversaId});

  Future<void> arquivar(int conversaId, {bool arquivar = true}) =>
      _call('arquivar', method: 'POST', body: {'conversa_id': conversaId, 'arquivar': arquivar});

  Future<void> bloquear(String tipo, int id, {required bool bloquear}) =>
      _call('bloquear', method: 'POST', body: {'tipo': tipo, 'id': id, 'bloquear': bloquear});

  Future<ChatInPreferencias> preferencias() async => ChatInPreferencias.fromJson(await _call('preferencias'));

  Future<ChatInPreferencias> salvarPreferencias(Map<String, bool> valores) async =>
      ChatInPreferencias.fromJson(await _call('preferencias', method: 'POST', body: valores));
}
