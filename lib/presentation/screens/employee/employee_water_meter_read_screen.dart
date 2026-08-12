import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/water_meter_offline_service.dart';
import '../../../core/offline/water_meter_sync_service.dart';
import '../../../core/ocr/water_meter_ocr_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/employee_auth_provider.dart';

class EmployeeWaterMeterReadScreen extends ConsumerStatefulWidget {
  const EmployeeWaterMeterReadScreen({
    required this.selection,
    super.key,
  });

  final Map<String, dynamic> selection;

  @override
  ConsumerState<EmployeeWaterMeterReadScreen> createState() =>
      _EmployeeWaterMeterReadScreenState();
}

class _EmployeeWaterMeterReadScreenState
    extends ConsumerState<EmployeeWaterMeterReadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _readingController = TextEditingController();
  final _observationController = TextEditingController();
  final _offline = WaterMeterOfflineService();
  final _ocr = WaterMeterOcrService();
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  String? _photoPath;
  WaterMeterOcrResult? _ocrResult;
  bool _processingPhoto = false;
  bool _confirmedOcr = false;
  bool _saving = false;

  Map<String, dynamic> get _resident =>
      Map<String, dynamic>.from(widget.selection['resident'] as Map);
  Map<String, dynamic> get _meter =>
      Map<String, dynamic>.from(widget.selection['meter'] as Map);

  @override
  void initState() {
    super.initState();
    final previous =
        double.tryParse(_meter['leitura_anterior']?.toString() ?? '') ?? 0;
    _readingController.text = previous.toStringAsFixed(3);
  }

  @override
  void dispose() {
    _readingController.dispose();
    _observationController.dispose();
    _offline.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final storage = await _offline.checkStorage();
    if (!storage.canStorePhoto) {
      _show(
        'Espaço insuficiente: libere pelo menos ${WaterMeterOfflineService.minimumFreeMb.toStringAsFixed(0)} MB antes de guardar foto offline.',
        danger: true,
      );
      return;
    }
    if (storage.warning) {
      _show(
          'O aparelho está com pouco espaço (${storage.freeMb.toStringAsFixed(0)} MB livres). Sincronize as pendências assim que possível.');
    }

    final source = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (source == null || !mounted) return;

    setState(() {
      _processingPhoto = true;
      _ocrResult = null;
      _confirmedOcr = false;
    });
    try {
      final photoPath = await _offline.storePhotoPrivately(
        sourcePath: source.path,
        clientUuid: _uuid.v4(),
      );
      final result = await _ocr.recognize(photoPath);
      if (!mounted) return;
      setState(() {
        _photoPath = photoPath;
        _ocrResult = result;
      });
      if (result.suggested != null) {
        _readingController.text = result.suggested!;
        _show(
            'Leitura sugerida pelo OCR. Confira os dígitos no medidor antes de confirmar.');
      } else {
        _show(
            'Não foi possível identificar uma leitura automaticamente. Informe o valor manualmente.',
            danger: true);
      }
    } catch (error) {
      _show(
          'Não foi possível processar a foto. Você pode informar a leitura manualmente.',
          danger: true);
    } finally {
      if (mounted) setState(() => _processingPhoto = false);
    }
  }

  Future<void> _queueReading() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_photoPath != null && !_confirmedOcr) {
      _show(
          'Confirme que conferiu a leitura sugerida pela foto antes de salvar.',
          danger: true);
      return;
    }
    final session = ref.read(employeeAuthProvider).session;
    final tenantData = session?['tenant'];
    final tenantId =
        tenantData is Map ? int.tryParse(tenantData['id'].toString()) : null;
    if (tenantId == null || tenantId <= 0) {
      _show('Não foi possível identificar o condomínio da sessão.',
          danger: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final reading = OfflineWaterReading(
        clientUuid: _uuid.v4(),
        tenantId: tenantId,
        hydrometerId: int.parse(_meter['id'].toString()),
        residentId: int.parse(_resident['id'].toString()),
        reading: double.parse(_readingController.text.replaceAll(',', '.')),
        readAt: DateTime.now(),
        observation: _observationController.text.trim(),
        photoPath: _photoPath,
        ocrText: _ocrResult?.rawText,
        ocrValue: _ocrResult?.suggested,
      );
      await _offline.enqueue(reading);
      final summary = await WaterMeterSyncService(
        ref.read(employeeApiProvider),
        _offline,
      ).syncPending(tenantId: tenantId);
      if (!mounted) return;
      final message = summary.offline
          ? 'Sem conexão: leitura e foto foram guardadas com segurança para sincronização posterior.'
          : summary.synced > 0
              ? 'Leitura sincronizada com sucesso.'
              : 'Leitura guardada no aparelho. A sincronização será tentada novamente quando houver conexão.';
      _show(message, danger: summary.failed > 0);
      context.go('/employee/water-meter');
    } catch (error) {
      _show('Não foi possível guardar a leitura no aparelho.', danger: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previous =
        double.tryParse(_meter['leitura_anterior']?.toString() ?? '') ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.go('/employee/water-meter'),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Voltar aos hidrômetros',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Lançar leitura',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: AppTheme.primary.withAlpha(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_resident['nome']?.toString() ?? 'Morador',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                    'Unidade: ${_meter['unidade'] ?? _resident['unidade'] ?? '—'}'),
                const Divider(height: 22),
                Text('Hidrômetro: ${_meter['numero_hidrometro'] ?? '—'}'),
                Text('Lacre: ${_meter['numero_lacre'] ?? 'Não informado'}'),
                Text('Última leitura: ${previous.toStringAsFixed(3)} m³'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _readingController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Leitura atual (m³)',
                      prefixIcon: Icon(Icons.speed_rounded),
                    ),
                    validator: (value) {
                      final current =
                          double.tryParse((value ?? '').replaceAll(',', '.'));
                      if (current == null || current < 0) {
                        return 'Informe uma leitura válida';
                      }
                      if (current < previous) {
                        return 'A leitura não pode ser menor que ${previous.toStringAsFixed(3)} m³';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _processingPhoto ? null : _capturePhoto,
                    icon: _processingPhoto
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.camera_alt_outlined),
                    label: Text(_photoPath == null
                        ? 'Fotografar hidrômetro e ler OCR'
                        : 'Refazer foto'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                  ),
                  const SizedBox(height: 10),
                  if (_photoPath != null) _photoCard(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observationController,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observação',
                      hintText: 'Opcional',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _queueReading,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_alt_rounded),
                      label: Text(_saving ? 'Guardando...' : 'Salvar leitura'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sem internet, a leitura e a foto ficam guardadas no armazenamento privado do aplicativo até a sincronização.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.file(File(_photoPath!), height: 180, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resultado OCR',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  _ocrResult?.suggested == null
                      ? 'Nenhuma leitura confiável encontrada. Informe manualmente.'
                      : 'Sugestão aplicada: ${_ocrResult!.suggested} m³',
                ),
                if ((_ocrResult?.candidates.length ?? 0) > 1)
                  Text(
                      'Outros números identificados: ${_ocrResult!.candidates.skip(1).take(4).join(', ')}'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmedOcr,
                  onChanged: (value) =>
                      setState(() => _confirmedOcr = value ?? false),
                  title: const Text('Conferi a leitura no visor do hidrômetro'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _show(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: danger ? AppTheme.danger : AppTheme.success),
    );
  }
}
