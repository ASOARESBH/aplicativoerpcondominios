/// Entidade de domínio do Hidrômetro
class WaterMeterEntity {
  final int id;
  final String? numeroHidrometro;
  final String? numeroLacre;
  final String? dataInstalacao;
  final bool ativo;

  const WaterMeterEntity({
    required this.id,
    this.numeroHidrometro,
    this.numeroLacre,
    this.dataInstalacao,
    required this.ativo,
  });
}

/// Entidade de Leitura do Hidrômetro
class WaterReadingEntity {
  final int id;
  final double? leituraAnterior;
  final double? leituraAtual;
  final double? consumo;
  final double? valorMetroCubico;
  final double? valorMinimo;
  final double? valorTotal;
  final String? dataLeitura;
  final String? observacao;

  const WaterReadingEntity({
    required this.id,
    this.leituraAnterior,
    this.leituraAtual,
    this.consumo,
    this.valorMetroCubico,
    this.valorMinimo,
    this.valorTotal,
    this.dataLeitura,
    this.observacao,
  });
}
