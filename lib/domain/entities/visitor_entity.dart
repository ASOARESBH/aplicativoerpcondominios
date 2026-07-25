/// Entidade de domínio do Visitante
class VisitorEntity {
  final int id;
  final String nomeCompleto;
  final String documento;
  final String tipoDocumento;
  final String? telefone;
  final String? celular;
  final String? email;
  final String? observacao;
  final bool ativo;
  final String? dataCadastro;

  const VisitorEntity({
    required this.id,
    required this.nomeCompleto,
    required this.documento,
    required this.tipoDocumento,
    this.telefone,
    this.celular,
    this.email,
    this.observacao,
    required this.ativo,
    this.dataCadastro,
  });
}

/// Entidade de Acesso (QR Code)
class AccessEntity {
  final int id;
  final int visitanteId;
  final String? visitanteNome;
  final String tipoVisitante;
  final String? placa;
  final String? modelo;
  final String? cor;
  final String dataInicial;
  final String dataFinal;
  final String tipoAcesso;
  final bool ativo;
  final int? diasPermanencia;

  const AccessEntity({
    required this.id,
    required this.visitanteId,
    this.visitanteNome,
    required this.tipoVisitante,
    this.placa,
    this.modelo,
    this.cor,
    required this.dataInicial,
    required this.dataFinal,
    required this.tipoAcesso,
    required this.ativo,
    this.diasPermanencia,
  });
}
