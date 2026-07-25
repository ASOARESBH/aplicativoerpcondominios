/// Validadores de formulário
class Validators {
  Validators._();

  static String? validateCpf(String? value) {
    if (value == null || value.isEmpty) return 'CPF é obrigatório';
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 11) return 'CPF inválido';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Senha é obrigatória';
    if (value.length < 6) return 'Mínimo de 6 caracteres';
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'E-mail é obrigatório';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) return 'E-mail inválido';
    return null;
  }

  static String? validateRequired(String? value, [String field = 'Campo']) {
    if (value == null || value.trim().isEmpty) return '$field é obrigatório';
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return null; // Optional
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return 'Telefone inválido';
    return null;
  }
}
