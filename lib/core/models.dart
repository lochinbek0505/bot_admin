import 'dart:convert';

enum HayGroup { animal, action, transport, nature, misc }
enum UserRole { admin, teacher, user }

HayGroup hayGroupFromString(String s) =>
    HayGroup.values.firstWhere((e) => e.name == s, orElse: () => HayGroup.misc);
UserRole userRoleFromString(String s) =>
    UserRole.values.firstWhere((e) => e.name == s, orElse: () => UserRole.user);

String? _optStr(Map<String, dynamic> j, String k) =>
    j[k] == null ? null : j[k].toString();

bool? _optBool(Map<String, dynamic> j, String k) =>
    j[k] is bool ? j[k] as bool : (j[k] == null ? null : j[k].toString() == 'true');

int? _optInt(Map<String, dynamic> j, String k) =>
    j[k] == null ? null : (j[k] is int ? j[k] as int : int.tryParse(j[k].toString()));

DateTime? _optDate(Map<String, dynamic> j, String k) =>
    j[k] == null ? null : DateTime.tryParse(j[k].toString());

class DiagnostikaItem {
  final int? id;
  String phrase;
  String imagePath; // /static/images/...
  bool enabled;
  int sortOrder;

  DiagnostikaItem({
    this.id,
    required this.phrase,
    required this.imagePath,
    required this.enabled,
    required this.sortOrder,
  });

  factory DiagnostikaItem.fromJson(Map<String, dynamic> j) => DiagnostikaItem(
    id: _optInt(j, 'id'),
    phrase: _optStr(j, 'phrase') ?? '',
    imagePath: _optStr(j, 'image_path') ?? '',
    enabled: j['enabled'] == true,
    sortOrder: _optInt(j, 'sort_order') ?? 0,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'phrase': phrase,
    'image_path': imagePath,
    'enabled': enabled,
    'sort_order': sortOrder,
  };
}

class HayvonItem {
  final int? id;
  String key;
  String title;
  HayGroup group;
  String imagePath; // /static/images/...
  String audioPath; // /static/audios/...
  bool enabled;
  int sortOrder;

  HayvonItem({
    this.id,
    required this.key,
    required this.title,
    required this.group,
    required this.imagePath,
    required this.audioPath,
    required this.enabled,
    required this.sortOrder,
  });

  factory HayvonItem.fromJson(Map<String, dynamic> j) => HayvonItem(
    id: _optInt(j, 'id'),
    key: _optStr(j, 'key') ?? '',
    title: _optStr(j, 'title') ?? '',
    group: hayGroupFromString(_optStr(j, 'group') ?? 'misc'),
    imagePath: _optStr(j, 'image_path') ?? '',
    audioPath: _optStr(j, 'audio_path') ?? '',
    enabled: j['enabled'] == true,
    sortOrder: _optInt(j, 'sort_order') ?? 0,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'key': key,
    'title': title,
    'group': group.name,
    'image_path': imagePath,
    'audio_path': audioPath,
    'enabled': enabled,
    'sort_order': sortOrder,
  };
}

class Darslik {
  final int? id;
  String code;
  String title;
  String text;
  String pdfPath; // /static/pdfs/...
  bool enabled;
  DateTime? createdAt;

  Darslik({
    this.id,
    required this.code,
    required this.title,
    required this.text,
    required this.pdfPath,
    required this.enabled,
    this.createdAt,
  });

  factory Darslik.fromJson(Map<String, dynamic> j) => Darslik(
    id: _optInt(j, 'id'),
    code: _optStr(j, 'code') ?? '',
    title: _optStr(j, 'title') ?? '',
    text: _optStr(j, 'text') ?? '',
    pdfPath: _optStr(j, 'pdf_path') ?? '',
    enabled: j['enabled'] == true,
    createdAt: _optDate(j, 'created_at'),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'code': code,
    'title': title,
    'text': text,
    'pdf_path': pdfPath,
    'enabled': enabled,
  };
}

class BotUser {
  final int? id;
  int tgId;
  String? username;
  String? fullName;
  UserRole role;
  bool isBlocked;
  String? notes;
  DateTime? createdAt;

  BotUser({
    this.id,
    required this.tgId,
    this.username,
    this.fullName,
    required this.role,
    required this.isBlocked,
    this.notes,
    this.createdAt,
  });

  factory BotUser.fromJson(Map<String, dynamic> j) => BotUser(
    id: _optInt(j, 'id'),
    tgId: _optInt(j, 'tg_id') ?? 0,
    username: _optStr(j, 'username'),
    fullName: _optStr(j, 'full_name'),
    role: userRoleFromString(_optStr(j, 'role') ?? 'user'),
    isBlocked: j['is_blocked'] == true,
    notes: _optStr(j, 'notes'),
    createdAt: _optDate(j, 'created_at'),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'tg_id': tgId,
    'username': username,
    'full_name': fullName,
    'role': role.name,
    'is_blocked': isBlocked,
    'notes': notes,
  };
}

// Simple totals/stat model (optional)
class Stats {
  final Map<String, num> totals;
  final Map<String, num> hayvonByGroup;
  final Map<String, num> usersByRole;

  Stats(this.totals, this.hayvonByGroup, this.usersByRole);
  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
    Map<String, num>.from(j['totals'] ?? {}),
    Map<String, num>.from(j['hayvon_by_group'] ?? {}),
    Map<String, num>.from(j['users_by_role'] ?? {}),
  );
}
