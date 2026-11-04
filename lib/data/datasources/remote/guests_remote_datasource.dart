import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/guest_entity.dart';

/// Acesso à API de Convidados do morador (`api/api_portal_convidados.php`).
///
/// O app sempre envia `canal=app`: o servidor grava a origem APP_MORADOR
/// (ou PORTAL_MORADOR, se a migration do ENUM ainda não foi aplicada).
/// Morador, unidade e autoria vêm do token — nunca do payload.
class GuestsRemoteDataSource {
  final DioClient _client;

  GuestsRemoteDataSource(this._client);

  Future<Map<String, dynamic>> _call(
    String acao, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    try {
      final params = <String, dynamic>{'acao': acao, 'canal': 'app', ...?query};
      final Response response = method == 'GET'
          ? await _client.dio.get(AppConstants.endpointConvidados, queryParameters: params)
          : await _client.dio.post(AppConstants.endpointConvidados, queryParameters: params, data: body ?? {});
      final data = response.data;
      if (data is! Map) throw const AppException('Resposta inválida do servidor.');
      final map = Map<String, dynamic>.from(data);
      if (response.statusCode == 401) throw const UnauthorizedException();
      if (map['sucesso'] != true) {
        throw AppException(map['mensagem']?.toString() ?? 'Não foi possível concluir a operação.',
            statusCode: response.statusCode);
      }
      return map;
    } on DioException catch (e) {
      final erro = e.error;
      if (erro is AppException) throw erro;
      throw AppException(e.message ?? 'Erro de comunicação com o servidor.');
    }
  }

  Map<String, dynamic> _dados(Map<String, dynamic> resposta) {
    final dados = resposta['dados'];
    return dados is Map ? Map<String, dynamic>.from(dados) : <String, dynamic>{};
  }

  Future<GuestFormOptions> opcoes() async =>
      GuestFormOptions.fromJson(_dados(await _call('opcoes')));

  /// [filtro]: `ativos` ou `historico`.
  Future<GuestListResult> listar({String filtro = 'ativos', int pagina = 1}) async {
    final dados = _dados(await _call('listar', query: {'filtro': filtro, 'pagina': pagina, 'limite': 20}));
    final itens = dados['convidados'];
    final resumo = dados['resumo'] is Map ? Map<String, dynamic>.from(dados['resumo']) : <String, dynamic>{};
    int n(String k) => int.tryParse(resumo[k]?.toString() ?? '') ?? 0;
    return GuestListResult(
      convidados: itens is List
          ? itens.whereType<Map>().map((e) => GuestEntity.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
      ativos: n('previstos') + n('presentes'),
      historico: n('historico'),
      pagina: int.tryParse(dados['pagina']?.toString() ?? '') ?? pagina,
      totalPaginas: int.tryParse(dados['total_paginas']?.toString() ?? '') ?? 1,
    );
  }

  /// Busca o documento em Visitantes (só retorna nome de visitante da unidade do morador).
  Future<GuestDocumentLookup> buscarDocumento(String tipoDocumento, String documento) async =>
      GuestDocumentLookup.fromJson(
          _dados(await _call('buscar_documento', query: {'tipo_documento': tipoDocumento, 'documento': documento})));

  Future<GuestEntity> obter(int id) async =>
      GuestEntity.fromJson(_dados(await _call('obter', query: {'id': id})));

  /// Retorna os títulos dos alertas ativos da unidade que podem afetar o convite.
  Future<List<String>> verificarAlertas(Map<String, dynamic> payload) async {
    final dados = _dados(await _call('verificar_alertas', method: 'POST', body: payload));
    final alertas = dados['alertas'];
    if (alertas is! List) return const [];
    return alertas.whereType<Map>().map((a) => a['titulo']?.toString() ?? '').where((t) => t.isNotEmpty).toList();
  }

  Future<String> criar(Map<String, dynamic> payload) async =>
      (await _call('criar', method: 'POST', body: payload))['mensagem']?.toString() ?? 'Convidado cadastrado.';

  Future<String> editar(int id, Map<String, dynamic> payload) async =>
      (await _call('editar', method: 'POST', body: {...payload, 'id': id}))['mensagem']?.toString() ??
      'Convidado atualizado.';

  Future<String> cancelar(int id, String motivo) async =>
      (await _call('cancelar', method: 'POST', body: {'id': id, 'motivo': motivo}))['mensagem']?.toString() ??
      'Convite cancelado.';
}

class GuestListResult {
  final List<GuestEntity> convidados;
  final int ativos;
  final int historico;
  final int pagina;
  final int totalPaginas;

  const GuestListResult({
    required this.convidados,
    required this.ativos,
    required this.historico,
    required this.pagina,
    required this.totalPaginas,
  });
}
