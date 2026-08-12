import 'dart:developer' as developer;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class WaterMeterOcrResult {
  const WaterMeterOcrResult({
    required this.rawText,
    required this.candidates,
  });

  final String rawText;
  final List<String> candidates;

  String? get suggested => candidates.isEmpty ? null : candidates.first;
}

/// OCR executado no próprio aparelho. O valor retornado é sempre uma sugestão:
/// a tela obriga a conferência e a confirmação humana antes do lançamento.
class WaterMeterOcrService {
  Future<WaterMeterOcrResult> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final candidates = _extractCandidates(recognized);
      developer.log(
        'OCR concluído; candidatos=${candidates.length}',
        name: 'LeituristaOCR',
      );
      return WaterMeterOcrResult(
        rawText: recognized.text,
        candidates: candidates,
      );
    } finally {
      await recognizer.close();
    }
  }

  List<String> _extractCandidates(RecognizedText text) {
    final values = <String>{};
    final expression = RegExp(r'(?<!\d)\d{3,8}(?:[,.]\d{1,3})?(?!\d)');

    // Analisa linhas primeiro, pois a leitura geralmente aparece isolada no visor.
    for (final block in text.blocks) {
      for (final line in block.lines) {
        for (final match in expression.allMatches(line.text)) {
          values.add(_normalize(match.group(0)!));
        }
      }
    }
    for (final match in expression.allMatches(text.text)) {
      values.add(_normalize(match.group(0)!));
    }

    final sorted = values.toList()
      ..sort((a, b) {
        final aa = double.tryParse(a) ?? -1;
        final bb = double.tryParse(b) ?? -1;
        // Mostradores de água costumam ter valores maiores que datas curtas; a
        // ordenação apenas ajuda a sugestão, sem dispensar a confirmação humana.
        return bb.compareTo(aa);
      });
    return sorted;
  }

  String _normalize(String value) => value.replaceAll(',', '.');
}
