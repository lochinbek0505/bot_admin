import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _baseUrl;
  late TextEditingController _apiKey;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _baseUrl = TextEditingController(text: app.baseUrl);
    _apiKey = TextEditingController(text: app.apiKey);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('API sozlamalari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'BASE_URL (masalan: http://185.217.131.39)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            decoration: const InputDecoration(
              labelText: 'API Key (X-API-Key, faqat mutatsiyalar uchun)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await app.saveSettings(baseUrl: _baseUrl.text, apiKey: _apiKey.text);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sozlamalar saqlandi va client yangilandi')),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save),
            label: const Text('Saqlash'),
          ),
          const Divider(height: 32),
          FilledButton.tonalIcon(
            onPressed: () async {
              try {
                final h = await app.service.health();
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Health check'),
                    content: Text(h.toString()),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Xato: $e')),
                );
              }
            },
            icon: const Icon(Icons.favorite),
            label: const Text('Health tekshirish (GET /)'),
          ),
        ],
      ),
    );
  }
}
