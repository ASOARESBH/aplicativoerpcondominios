/// Convidado (pré-cadastro do morador para a Lista de Convidados da portaria).
///
/// Espelha o JSON de `api/api_portal_convidados.php`. Morador, unidade e origem
/// são definidos pelo servidor; o app apenas exibe.
class GuestEntity {
  final int id;
  final String nome;
  final String tipoConvidado;
  final String tipoDocumento;
  final String documentoMascarado;
  final String? documento; // só vem no detalhe de convites cadastrados pelo próprio morador
  final String anfitriaoTipo;
  final int? dependenteId;
  final String? anfitriaoNome;
  final int? visitanteId;
  final String dataPrevistaChegada;
  final int diasPermanencia;
  final String validadeFim;
  final String modalidadeEntradas;
  final int? limiteEntradas;
  final int entradasUtilizadas;
  final String origemCadastro;
  final String statusExibicao;
  final String? observacao;
  final String cadastradoPorNome;
  final String criadoEm;
  final String? motivoCancelamento;
  final bool cadastroProprio;
  final bool podeEditar;
  final bool podeCancelar;
  final List<GuestMovement> movimentacoes;

  const GuestEntity({
    required this.id,
    required this.nome,
    required this.tipoConvidado,
    required this.tipoDocumento,
    required this.documentoMascarado,
    this.documento,
    required this.anfitriaoTipo,
    this.dependenteId,
    this.anfitriaoNome,
    this.visitanteId,
    required this.dataPrevistaChegada,
    required this.diasPermanencia,
    required this.validadeFim,
    required this.modalidadeEntradas,
    this.limiteEntradas,
    required this.entradasUtilizadas,
    required this.origemCadastro,
    required this.statusExibicao,
    this.observacao,
    required this.cadastradoPorNome,
    required this.criadoEm,
    this.motivoCancelamento,
    required this.cadastroProprio,
    required this.podeEditar,
    required this.podeCancelar,
    this.movimentacoes = const [],
  });

  static int? _intOrNull(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static String _str(dynamic v) => v?.toString() ?? '';

  factory GuestEntity.fromJson(Map<String, dynamic> json) {
    final movs = json['movimentacoes'];
    return GuestEntity(
      id: _int(json['id']),
      nome: _str(json['nome']),
      tipoConvidado: _str(json['tipo_convidado']),
      tipoDocumento: _str(json['tipo_documento']),
      documentoMascarado: _str(json['documento_mascarado']),
      documento: json['documento']?.toString(),
      anfitriaoTipo: _str(json['anfitriao_tipo']),
      dependenteId: _intOrNull(json['dependente_id']),
      anfitriaoNome: json['anfitriao_nome']?.toString(),
      visitanteId: _intOrNull(json['visitante_id']),
      dataPrevistaChegada: _str(json['data_prevista_chegada']),
      diasPermanencia: _int(json['dias_permanencia']),
      validadeFim: _str(json['validade_fim']),
      modalidadeEntradas: _str(json['modalidade_entradas']),
      limiteEntradas: _intOrNull(json['limite_entradas']),
      entradasUtilizadas: _int(json['entradas_utilizadas']),
      origemCadastro: _str(json['origem_cadastro']),
      statusExibicao: _str(json['status_exibicao']),
      observacao: (json['observacao']?.toString().isEmpty ?? true) ? null : json['observacao'].toString(),
      cadastradoPorNome: _str(json['cadastrado_por_nome']),
      criadoEm: _str(json['criado_em']),
      motivoCancelamento: json['motivo_cancelamento']?.toString(),
      cadastroProprio: json['cadastro_proprio'] == true,
      podeEditar: json['pode_editar'] == true,
      podeCancelar: json['pode_cancelar'] == true,
      movimentacoes: movs is List
          ? movs.whereType<Map>().map((m) => GuestMovement.fromJson(Map<String, dynamic>.from(m))).toList()
          : const [],
    );
  }

  String get entradasTexto => limiteEntradas == null
      ? '$entradasUtilizadas (livres no período)'
      : '$entradasUtilizadas de $limiteEntradas';
}

class GuestMovement {
  final String dataHora;
  final String tipoAcesso;

  const GuestMovement({required this.dataHora, required this.tipoAcesso});

  factory GuestMovement.fromJson(Map<String, dynamic> json) => GuestMovement(
        dataHora: json['data_hora']?.toString() ?? '',
        tipoAcesso: json['tipo_acesso']?.toString() ?? '',
      );
}

/// Resultado da busca do documento digitado em Visitantes.
/// [encontrado] só é verdadeiro para visitante da unidade do morador.
class GuestDocumentLookup {
  final bool encontrado;
  final int? visitanteId;
  final String? nome;
  final String mensagem;

  const GuestDocumentLookup({required this.encontrado, this.visitanteId, this.nome, required this.mensagem});

  factory GuestDocumentLookup.fromJson(Map<String, dynamic> json) => GuestDocumentLookup(
        encontrado: json['encontrado'] == true,
        visitanteId: json['visitante_id'] == null ? null : int.tryParse(json['visitante_id'].toString()),
        nome: json['nome']?.toString(),
        mensagem: json['mensagem']?.toString() ??
            'Visitante não cadastrado. Informe o nome completo: ao salvar, ele será cadastrado em Visitantes da sua unidade.',
      );
}

/// Opções do formulário (tipos, modalidades, dependentes e visitantes da unidade).
class GuestFormOptions {
  final String unidade;
  final List<GuestOption> tipos;
  final List<GuestEntryOption> modalidades;
  final List<GuestOption> dependentes;
  final List<GuestOption> visitantes;
  final int diasPermanenciaMax;

  const GuestFormOptions({
    required this.unidade,
    required this.tipos,
    required this.modalidades,
    required this.dependentes,
    required this.visitantes,
    required this.diasPermanenciaMax,
  });

  factory GuestFormOptions.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> lista(dynamic v) =>
        v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
    return GuestFormOptions(
      unidade: (json['morador'] is Map ? json['morador']['unidade'] : '')?.toString() ?? '',
      tipos: lista(json['tipos']).map((t) => GuestOption(t['valor'].toString(), t['rotulo'].toString())).toList(),
      modalidades: lista(json['modalidades'])
          .map((m) => GuestEntryOption(
                m['valor'].toString(),
                m['rotulo'].toString(),
                m['limite_entradas'] == null ? null : int.tryParse(m['limite_entradas'].toString()),
              ))
          .toList(),
      dependentes: lista(json['dependentes']).map((d) => GuestOption(d['id'].toString(), d['nome'].toString())).toList(),
      visitantes: lista(json['visitantes'])
          .map((v) => GuestOption(v['id'].toString(), '${v['nome']} — ${v['tipo_documento']} ${v['documento_mascarado']}'))
          .toList(),
      diasPermanenciaMax: int.tryParse(json['dias_permanencia_max']?.toString() ?? '') ?? 365,
    );
  }
}

class GuestOption {
  final String value;
  final String label;
  const GuestOption(this.value, this.label);
}

class GuestEntryOption {
  final String modalidade;
  final String label;
  final int? limite;
  const GuestEntryOption(this.modalidade, this.label, this.limite);

  /// Chave única do item no dropdown (MULTIPLO aparece com vários limites).
  String get key => '$modalidade|${limite ?? ''}';
}
