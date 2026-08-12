import 'dart:developer' as developer;
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../network/employee_api_client.dart';
import 'water_meter_offline_service.dart';

class WaterMeterSyncSummary {
  const WaterMeterSyncSummary({
    required this.synced,
    required this.failed,
    required this.offline,
  });

  final int synced;
  final int failed;
  final bool offline;
}

/// Envia pendências apenas quando existe rede. A API usa client_uuid para tornar
/// repetição após queda de conexão segura e idempotente.
class WaterMeterSyncService {
  WaterMeterSyncService(this._api, this._offline);

  final EmployeeApiClient _api;
  final WaterMeterOfflineService _offline;
  bool _running = false;

  Future<WaterMeterSyncSummary> syncPending({required int tenantId}) async {
    if (_running) {
      return const WaterMeterSyncSummary(synced: 0, failed: 0, offline: false);
    }
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return const WaterMeterSyncSummary(synced: 0, failed: 0, offline: true);
    }

    _running = true;
    var synced = 0;
    var failed = 0;
    try {
      final pending = await _offline.pending(tenantId: tenantId);
      for (final item in pending) {
        if (item.localId == null) continue;
        try {
          await _offline.markUploading(item.localId!);
          var photoId = item.serverPhotoId;
          if (photoId == null && item.photoPath != null) {
            final photo = File(item.photoPath!);
            if (!await photo.exists()) {
              throw StateError(
                  'A foto privada desta leitura não foi encontrada no aparelho.');
            }
            final response = await _api.postForm(
              AppConstants.actionFotoHidrometro,
              FormData.fromMap({
                'hidrometro_id': item.hydrometerId.toString(),
                'client_uuid': item.clientUuid,
                'arquivo': await MultipartFile.fromFile(
                  photo.path,
                  filename: 'hidrometro_${item.clientUuid}.jpg',
                ),
              }),
            );
            final data = response.data;
            if (data is! Map ||
                data['sucesso'] != true ||
                data['dados'] is! Map) {
              throw StateError(_message(data));
            }
            photoId = int.tryParse((data['dados'] as Map)['id'].toString());
            if (photoId == null || photoId <= 0) {
              throw StateError(
                  'O servidor não retornou a identificação da foto.');
            }
            await _offline.markPhotoUploaded(item.localId!, photoId);
          }

          final response = await _api.post(
            AppConstants.actionRegistrarLeituraHidrometro,
            data: {
              'hidrometro_id': item.hydrometerId,
              'client_uuid': item.clientUuid,
              'leitura_atual': item.reading,
              'data_leitura': _formatDateTime(item.readAt),
              'observacao': item.observation,
              if (photoId != null) 'foto_id': photoId,
            },
          );
          final data = response.data;
          if (data is! Map || data['sucesso'] != true) {
            throw StateError(_message(data));
          }
          await _offline.markSyncedAndDelete(item);
          synced++;
          developer.log(
            'Leitura sincronizada; hidrômetro=${item.hydrometerId}',
            name: 'LeituristaSync',
          );
        } catch (error) {
          failed++;
          final message = _message(error);
          await _offline.markFailed(item.localId!, message);
          developer.log(
            'Falha ao sincronizar hidrômetro=${item.hydrometerId}: $message',
            name: 'LeituristaSync',
          );
        }
      }
    } finally {
      _running = false;
    }
    return WaterMeterSyncSummary(
        synced: synced, failed: failed, offline: false);
  }

  String _formatDateTime(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  String _message(dynamic value) {
    if (value is DioException) {
      return _message(value.response?.data);
    }
    if (value is StateError) {
      return value.message;
    }
    if (value is Map && value['mensagem'] != null) {
      return value['mensagem'].toString();
    }
    return 'Não foi possível sincronizar esta leitura.';
  }
}
