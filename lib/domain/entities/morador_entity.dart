/// Entidade de domínio do Morador
class MoradorEntity {
  final int id;
  final String nome;
  final String? cpf;
  final String unidade;
  final String? email;
  final String? telefone;
  final String? celular;
  final bool ativo;
  final String? ultimoAcesso;

  const MoradorEntity({
    required this.id,
    required this.nome,
    this.cpf,
    required this.unidade,
    this.email,
    this.telefone,
    this.celular,
    required this.ativo,
    this.ultimoAcesso,
  });
}

/// Entidade de sessão do morador (armazenada localmente)
class MoradorSessionEntity {
  final String token;
  final int moradorId;
  final String nome;
  final String unidade;
  final String? email;
  final String? tenantId;
  final bool senhaTemporaria;

  const MoradorSessionEntity({
    required this.token,
    required this.moradorId,
    required this.nome,
    required this.unidade,
    this.email,
    this.tenantId,
    this.senhaTemporaria = false,
  });
}
