import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/api_client.dart';
import '../core/models.dart';

class AdminService {
  final ApiClient _c;
  AdminService(this._c);

  Options? _auth() {
    final k = _c.currentApiKey;
    if (k == null || k.isEmpty) return null;
    return Options(headers: {'X-API-Key': k});
  }

  // ---------- HEALTH ----------
  Future<Map<String, dynamic>> health() async {
    final r = await _c.dio.get('/');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ---------- DIAGNOSTIKA ----------
  Future<List<DiagnostikaItem>> diagnostikaList({bool? enabled}) async {
    final r = await _c.dio.get('/diagnostika', queryParameters: {
      if (enabled != null) 'enabled': enabled,
    });
    return (r.data as List).cast<Map<String, dynamic>>().map(DiagnostikaItem.fromJson).toList();
  }

  Future<DiagnostikaItem> diagnostikaCreate(DiagnostikaItem item) async {
    final r = await _c.dio.post('/diagnostika', data: item.toJson(), options: _auth());
    return DiagnostikaItem.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<DiagnostikaItem> diagnostikaUpdate(int id, DiagnostikaItem item) async {
    final r = await _c.dio.put('/diagnostika/$id', data: item.toJson(), options: _auth());
    return DiagnostikaItem.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<void> diagnostikaDelete(int id) async {
    await _c.dio.delete('/diagnostika/$id', options: _auth());
  }

  Future<List<Map<String, dynamic>>> diagnostikaExport() async {
    final r = await _c.dio.get('/export/diagnostika');
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  // ---------- HAYVON ----------
  Future<List<HayvonItem>> hayvonList({bool? enabled, HayGroup? group}) async {
    final r = await _c.dio.get('/hayvon', queryParameters: {
      if (enabled != null) 'enabled': enabled,
      if (group != null) 'group': group.name,
    });
    return (r.data as List).cast<Map<String, dynamic>>().map(HayvonItem.fromJson).toList();
  }

  Future<HayvonItem> hayvonCreate(HayvonItem item) async {
    final r = await _c.dio.post('/hayvon', data: item.toJson(), options: _auth());
    return HayvonItem.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<HayvonItem> hayvonUpdate(int id, HayvonItem item) async {
    final r = await _c.dio.put('/hayvon/$id', data: item.toJson(), options: _auth());
    return HayvonItem.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<void> hayvonDelete(int id) async {
    await _c.dio.delete('/hayvon/$id', options: _auth());
  }

  Future<List<Map<String, dynamic>>> hayvonExport({bool? enabledOnly, HayGroup? group}) async {
    final r = await _c.dio.get('/export/hayvon', queryParameters: {
      if (enabledOnly != null) 'enabled_only': enabledOnly,
      if (group != null) 'group': group.name,
    });
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  // ---------- DARSLIK ----------
  Future<List<Darslik>> darslikList({String? code, String? title, bool? enabled}) async {
    final r = await _c.dio.get('/darslik', queryParameters: {
      if (code != null && code.isNotEmpty) 'code': code,
      if (title != null && title.isNotEmpty) 'title': title,
      if (enabled != null) 'enabled': enabled,
    });
    return (r.data as List).cast<Map<String, dynamic>>().map(Darslik.fromJson).toList();
  }

  Future<Darslik> darslikCreate(Darslik item) async {
    final r = await _c.dio.post('/darslik', data: item.toJson(), options: _auth());
    return Darslik.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<Darslik> darslikUpdate(int id, Darslik item) async {
    final r = await _c.dio.put('/darslik/$id', data: item.toJson(), options: _auth());
    return Darslik.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<void> darslikDelete(int id) async {
    await _c.dio.delete('/darslik/$id', options: _auth());
  }

  Future<Darslik> darslikByCode(String code) async {
    final r = await _c.dio.get('/darslik/by-code/$code');
    return Darslik.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<Map<String, dynamic>> darslikExportByCode(String code) async {
    final r = await _c.dio.get('/export/darslik/$code');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ---------- USERS ----------
  Future<List<BotUser>> usersList({bool? blocked, String? username, UserRole? role}) async {
    final r = await _c.dio.get('/users', queryParameters: {
      if (blocked != null) 'blocked': blocked,
      if (username != null && username.isNotEmpty) 'username': username,
      if (role != null) 'role': role.name,
    });
    return (r.data as List).cast<Map<String, dynamic>>().map(BotUser.fromJson).toList();
  }

  Future<BotUser> userCreate(BotUser u) async {
    final r = await _c.dio.post('/users', data: u.toJson(), options: _auth());
    return BotUser.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<BotUser> userUpdate(int id, BotUser u) async {
    final r = await _c.dio.put('/users/$id', data: u.toJson(), options: _auth());
    return BotUser.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<void> userDelete(int id) async {
    await _c.dio.delete('/users/$id', options: _auth());
  }

  Future<BotUser> userUpsert({
    required int tgId,
    String? username,
    String? fullName,
    UserRole? role,
    String? notes,
  }) async {
    final form = FormData.fromMap({
      'tg_id': tgId,
      if (username != null) 'username': username,
      if (fullName != null) 'full_name': fullName,
      if (role != null) 'role': role.name,
      if (notes != null) 'notes': notes,
    });
    final r = await _c.dio.post('/users/upsert', data: form, options: _auth());
    return BotUser.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<BotUser> userBlock(int id) async {
    final r = await _c.dio.post('/users/$id/block', options: _auth());
    return BotUser.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<BotUser> userUnblock(int id) async {
    final r = await _c.dio.post('/users/$id/unblock', options: _auth());
    return BotUser.fromJson(Map<String, dynamic>.from(r.data));
  }

  // ---------- UPLOADS ----------
  Future<String> uploadImage(PlatformFile file) async {
    final form = FormData();
    if (kIsWeb) {
      form.files.add(MapEntry('file', MultipartFile.fromBytes(file.bytes!, filename: file.name)));
    } else {
      form.files.add(MapEntry('file', await MultipartFile.fromFile(file.path!, filename: file.name)));
    }
    final r = await _c.dio.post('/upload/image', data: form, options: _auth());
    return (r.data as Map)['url'] as String;
  }

  Future<String> uploadPdf(PlatformFile file) async {
    final form = FormData();
    if (kIsWeb) {
      form.files.add(MapEntry('file', MultipartFile.fromBytes(file.bytes!, filename: file.name)));
    } else {
      form.files.add(MapEntry('file', await MultipartFile.fromFile(file.path!, filename: file.name)));
    }
    final r = await _c.dio.post('/upload/pdf', data: form, options: _auth());
    return (r.data as Map)['url'] as String;
  }

  Future<String> uploadAudio(PlatformFile file) async {
    final form = FormData();
    if (kIsWeb) {
      form.files.add(MapEntry('file', MultipartFile.fromBytes(file.bytes!, filename: file.name)));
    } else {
      form.files.add(MapEntry('file', await MultipartFile.fromFile(file.path!, filename: file.name)));
    }
    final r = await _c.dio.post('/upload/audio', data: form, options: _auth());
    return (r.data as Map)['url'] as String;
  }
}
