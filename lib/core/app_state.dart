import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_service.dart';
import 'api_client.dart';

class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;
  late ApiClient client;
  late AdminService service;

  String baseUrl = '';
  String apiKey = '';
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    baseUrl = (_prefs.getString('baseUrl') ?? '').trim();
    apiKey  = (_prefs.getString('apiKey')  ?? '').trim();

    if (baseUrl.isEmpty) {
      baseUrl = 'http://185.217.131.39'; // default
    }

    client  = ApiClient(baseUrl: baseUrl, apiKey: apiKey);
    service = AdminService(client);

    _ready = true;
    notifyListeners();
  }

  Future<void> saveSettings({required String baseUrl, required String apiKey}) async {
    final b = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final k = apiKey.trim();

    await _prefs.setString('baseUrl', b);
    await _prefs.setString('apiKey', k);

    this.baseUrl = b;
    this.apiKey  = k;

    client.updateBaseUrl(b);
    client.updateApiKey(k);

    notifyListeners();
  }

  String toFullUrl(String p) => client.toFullUrl(p);
}
