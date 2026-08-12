import 'dart:developer' as developer;
import 'dart:io';

import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Pendência de leitura guardada no armazenamento privado do aplicativo.
/// As fotos não são salvas na galeria e permanecem privadas até a sincronização.
class OfflineWaterReading {
  const OfflineWaterReading({
    this.localId,
    required this.clientUuid,
    required this.tenantId,
    required this.hydrometerId,
    required this.residentId,
    required this.reading,
    required this.readAt,
    required this.observation,
    this.photoPath,
    this.ocrText,
    this.ocrValue,
    this.serverPhotoId,
    this.syncState = 'pending',
    this.lastError,
    this.attempts = 0,
  });

  final int? localId;
  final String clientUuid;
  final int tenantId;
  final int hydrometerId;
  final int residentId;
  final double reading;
  final DateTime readAt;
  final String observation;
  final String? photoPath;
  final String? ocrText;
  final String? ocrValue;
  final int? serverPhotoId;
  final String syncState;
  final String? lastError;
  final int attempts;

  Map<String, Object?> toMap() => {
        'id': localId,
        'client_uuid': clientUuid,
        'tenant_id': tenantId,
        'hidrometro_id': hydrometerId,
        'morador_id': residentId,
        'leitura_atual': reading,
        'data_leitura': readAt.toIso8601String(),
        'observacao': observation,
        'foto_path': photoPath,
        'ocr_texto': ocrText,
        'ocr_valor': ocrValue,
        'foto_servidor_id': serverPhotoId,
        'sync_state': syncState,
        'ultimo_erro': lastError,
        'tentativas': attempts,
        'atualizado_em': DateTime.now().toIso8601String(),
      };

  factory OfflineWaterReading.fromMap(Map<String, Object?> map) {
    return OfflineWaterReading(
      localId: map['id'] as int?,
      clientUuid: map['client_uuid'] as String,
      tenantId: map['tenant_id'] as int,
      hydrometerId: map['hidrometro_id'] as int,
      residentId: map['morador_id'] as int,
      reading: (map['leitura_atual'] as num).toDouble(),
      readAt: DateTime.parse(map['data_leitura'] as String),
      observation: (map['observacao'] as String?) ?? '',
      photoPath: map['foto_path'] as String?,
      ocrText: map['ocr_texto'] as String?,
      ocrValue: map['ocr_valor'] as String?,
      serverPhotoId: map['foto_servidor_id'] as int?,
      syncState: (map['sync_state'] as String?) ?? 'pending',
      lastError: map['ultimo_erro'] as String?,
      attempts: (map['tentativas'] as int?) ?? 0,
    );
  }
}

class StorageCheck {
  const StorageCheck({required this.freeMb, required this.canStorePhoto});

  final double freeMb;
  final bool canStorePhoto;

  bool get warning => freeMb >= 200 && freeMb < 500;
}

class WaterMeterOfflineService {
  WaterMeterOfflineService();

  static const _dbName = 'erp_leiturista_offline.db';
  static const _table = 'leituras_pendentes';
  static const double minimumFreeMb = 200;
  static const double warningFreeMb = 500;

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final base = await getDatabasesPath();
    _database = await openDatabase(
      path.join(base, _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_uuid TEXT NOT NULL UNIQUE,
            tenant_id INTEGER NOT NULL,
            hidrometro_id INTEGER NOT NULL,
            morador_id INTEGER NOT NULL,
            leitura_atual REAL NOT NULL,
            data_leitura TEXT NOT NULL,
            observacao TEXT NOT NULL DEFAULT '',
            foto_path TEXT,
            ocr_texto TEXT,
            ocr_valor TEXT,
            foto_servidor_id INTEGER,
            sync_state TEXT NOT NULL DEFAULT 'pending',
            ultimo_erro TEXT,
            tentativas INTEGER NOT NULL DEFAULT 0,
            criado_em TEXT NOT NULL,
            atualizado_em TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_leituras_pendentes_tenant_estado ON $_table (tenant_id, sync_state)',
        );
      },
    );
    return _database!;
  }

  Future<StorageCheck> checkStorage() async {
    try {
      final free = await DiskSpacePlus().getFreeDiskSpace ?? 0;
      return StorageCheck(
        freeMb: free,
        canStorePhoto: free >= minimumFreeMb,
      );
    } catch (error) {
      developer.log(
        'Não foi possível consultar espaço livre: ${error.runtimeType}',
        name: 'LeituristaOffline',
      );
      // Se a plataforma não expuser o número de MB, mantém o fluxo funcional,
      // mas a tela informa que não conseguiu estimar o espaço disponível.
      return const StorageCheck(freeMb: -1, canStorePhoto: true);
    }
  }

  Future<String> storePhotoPrivately({
    required String sourcePath,
    required String clientUuid,
  }) async {
    final storage = await checkStorage();
    if (!storage.canStorePhoto) {
      throw StateError(
        'Espaço insuficiente no aparelho. Libere pelo menos ${minimumFreeMb.toStringAsFixed(0)} MB para salvar fotos offline.',
      );
    }
    final supportDir = await getApplicationSupportDirectory();
    final photosDir =
        Directory(path.join(supportDir.path, 'leiturista', 'fotos'));
    if (!await photosDir.exists()) await photosDir.create(recursive: true);
    final extension = path.extension(sourcePath).isEmpty
        ? '.jpg'
        : path.extension(sourcePath).toLowerCase();
    final target = File(path.join(photosDir.path, '$clientUuid$extension'));
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  Future<int> enqueue(OfflineWaterReading reading) async {
    final db = await _db;
    final values = reading.toMap()
      ..remove('id')
      ..putIfAbsent('criado_em', () => DateTime.now().toIso8601String());
    final id = await db.insert(
      _table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    developer.log(
      'Leitura adicionada à fila offline: $id',
      name: 'LeituristaOffline',
    );
    return id;
  }

  Future<List<OfflineWaterReading>> pending({int? tenantId}) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: tenantId == null
          ? "sync_state != 'synced'"
          : 'tenant_id = ? AND sync_state != \'synced\'',
      whereArgs: tenantId == null ? null : [tenantId],
      orderBy: 'criado_em ASC',
    );
    return rows
        .map((row) =>
            OfflineWaterReading.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<int> pendingCount({int? tenantId}) async {
    final db = await _db;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            tenantId == null
                ? "SELECT COUNT(*) FROM $_table WHERE sync_state != 'synced'"
                : "SELECT COUNT(*) FROM $_table WHERE tenant_id = ? AND sync_state != 'synced'",
            tenantId == null ? null : [tenantId],
          ),
        ) ??
        0;
  }

  Future<void> markUploading(int id) =>
      _update(id, {'sync_state': 'syncing', 'ultimo_erro': null});

  Future<void> markPhotoUploaded(int id, int photoId) => _update(id, {
        'foto_servidor_id': photoId,
        'sync_state': 'pending',
        'ultimo_erro': null
      });

  Future<void> markFailed(int id, String message) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE $_table SET sync_state = ?, ultimo_erro = ?, tentativas = tentativas + 1, atualizado_em = ? WHERE id = ?',
      [
        'failed',
        message.substring(0, message.length > 500 ? 500 : message.length),
        DateTime.now().toIso8601String(),
        id
      ],
    );
  }

  Future<void> markSyncedAndDelete(OfflineWaterReading reading) async {
    if (reading.photoPath != null) {
      final photo = File(reading.photoPath!);
      if (await photo.exists()) await photo.delete();
    }
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [reading.localId]);
    developer.log('Leitura offline sincronizada e removida.',
        name: 'LeituristaOffline');
  }

  Future<void> discard(OfflineWaterReading reading) async {
    if (reading.photoPath != null) {
      final photo = File(reading.photoPath!);
      if (await photo.exists()) await photo.delete();
    }
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [reading.localId]);
  }

  Future<void> _update(int id, Map<String, Object?> values) async {
    final db = await _db;
    values['atualizado_em'] = DateTime.now().toIso8601String();
    await db.update(_table, values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> dispose() async {
    final db = _database;
    _database = null;
    if (db != null) await db.close();
  }
}
