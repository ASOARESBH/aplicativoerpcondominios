import '../../domain/entities/morador_entity.dart';

/// Modelo de dados do Morador (camada de dados)
class MoradorModel extends MoradorEntity {
  const MoradorModel({
    required super.id,
    required super.nome,
    super.cpf,
    required super.unidade,
    super.email,
    super.telefone,
    super.celular,
    required super.ativo,
    super.ultimoAcesso,
  });

  factory MoradorModel.fromJson(Map<String, dynamic> json) {
    return MoradorModel(
      id: _parseInt(json['id']),
      nome: json['nome']?.toString() ?? '',
      cpf: json['cpf']?.toString(),
      unidade: json['unidade']?.toString() ?? '',
      email: json['email']?.toString(),
      telefone: json['telefone']?.toString(),
      celular: json['celular']?.toString(),
      ativo: json['ativo'] == 1 || json['ativo'] == '1' || json['ativo'] == true,
      ultimoAcesso: json['ultimo_acesso']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'cpf': cpf,
      'unidade': unidade,
      'email': email,
      'telefone': telefone,
      'celular': celular,
      'ativo': ativo ? 1 : 0,
      'ultimo_acesso': ultimoAcesso,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Modelo de resposta do Login
class LoginResponseModel {
  final bool sucesso;
  final String mensagem;
  final String? token;
  final int? moradorId;
  final String? nome;
  final String? unidade;
  final String? email;
  final bool senhaTemporaria;

  const LoginResponseModel({
    required this.sucesso,
    required this.mensagem,
    this.token,
    this.moradorId,
    this.nome,
    this.unidade,
    this.email,
    this.senhaTemporaria = false,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final dados = json['dados'] as Map<String, dynamic>?;
    return LoginResponseModel(
      sucesso: json['sucesso'] == true,
      mensagem: json['mensagem']?.toString() ?? '',
      token: dados?['token']?.toString() ?? json['token']?.toString(),
      moradorId: _parseInt(dados?['morador_id'] ?? json['morador_id']),
      // API retorna 'morador_nome' (não 'nome') dentro de dados
      nome: dados?['morador_nome']?.toString()
          ?? dados?['nome']?.toString()
          ?? json['morador_nome']?.toString()
          ?? json['nome']?.toString(),
      unidade: dados?['unidade']?.toString() ?? json['unidade']?.toString(),
      email: dados?['email']?.toString() ?? json['email']?.toString(),
      senhaTemporaria: dados?['senha_temporaria'] == 1 ||
          dados?['senha_temporaria'] == '1' ||
          dados?['senha_temporaria'] == true,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
