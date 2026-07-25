/// Entidade de domínio do Chamado (Ordem de Serviço)
class TicketEntity {
  final int id;
  final String numero;
  final String titulo;
  final String? descricao;
  final String status;
  final String prioridade;
  final String? assuntoNome;
  final String? departamento;
  final String? assumidoPorNome;
  final String? dataAbertura;
  final int totalInteracoes;

  const TicketEntity({
    required this.id,
    required this.numero,
    required this.titulo,
    this.descricao,
    required this.status,
    required this.prioridade,
    this.assuntoNome,
    this.departamento,
    this.assumidoPorNome,
    this.dataAbertura,
    this.totalInteracoes = 0,
  });
}

/// Entidade de Assunto do Chamado
class TicketSubjectEntity {
  final int id;
  final String nome;
  final String? departamento;

  const TicketSubjectEntity({
    required this.id,
    required this.nome,
    this.departamento,
  });
}

/// Entidade de Interação no Chamado
class TicketInteractionEntity {
  final int id;
  final String mensagem;
  final String? autorNome;
  final String? dataInteracao;
  final bool isPublica;

  const TicketInteractionEntity({
    required this.id,
    required this.mensagem,
    this.autorNome,
    this.dataInteracao,
    required this.isPublica,
  });
}
