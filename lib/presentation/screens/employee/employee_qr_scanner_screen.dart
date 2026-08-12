import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';

class EmployeeQrScannerScreen extends StatefulWidget {
  const EmployeeQrScannerScreen({super.key});

  @override
  State<EmployeeQrScannerScreen> createState() =>
      _EmployeeQrScannerScreenState();
}

class _EmployeeQrScannerScreenState extends State<EmployeeQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _handled = false;
  String? _cameraError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .firstWhere(
          (code) => code.isNotEmpty,
          orElse: () => '',
        );
    if (value.isEmpty) return;

    _handled = true;
    developer.log('Código lido pela câmera.', name: 'ColaboradorQR');
    await _controller.stop();
    if (mounted) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ler QR Code ou código de barras'),
        actions: [
          IconButton(
            tooltip: 'Alternar lanterna',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_rounded),
          ),
          IconButton(
            tooltip: 'Trocar câmera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: _cameraError != null
          ? _errorBody()
          : Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    developer.log('Câmera indisponível: ${error.errorCode}',
                        name: 'ColaboradorQR');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(
                          () => _cameraError =
                              'Não foi possível abrir a câmera. Verifique a permissão de câmera do aplicativo.',
                        );
                      }
                    });
                    return const SizedBox.shrink();
                  },
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AppTheme.primaryLight, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 42,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Posicione o QR Code ou código de barras dentro do quadro. A leitura será feita automaticamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _errorBody() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined,
              color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            _cameraError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar'),
          ),
        ],
      ),
    );
  }
}
