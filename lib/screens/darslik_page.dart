import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';

class DarslikPage extends StatefulWidget {
  const DarslikPage({super.key});
  @override
  State<DarslikPage> createState() => _DarslikPageState();
}

class _DarslikPageState extends State<DarslikPage> {
  Future<List<Darslik>>? _future;
  String _code = '';
  String _title = '';
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    // initState ichida setState chaqirmaymiz
    final s = context.read<AppState>().service;
    _future = s.darslikList(code: null, title: null, enabled: _enabled);
  }

  void _reload() {
    final s = context.read<AppState>().service;
    final f = s.darslikList(
      code: _code.isEmpty ? null : _code,
      title: _title.isEmpty ? null : _title,
      enabled: _enabled,
    );
    setState(() {
      _future = f; // callback hech narsa QAYTARMAYDI (void) — xatolik bo‘lmaydi
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: Column(
        children: [
          // Filter panel — Wrap yordamida; Expanded/Spacer ishlatilmaydi.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Code filter'),
                    onChanged: (v) => _code = v,
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Title filter'),
                    onChanged: (v) => _title = v,
                  ),
                ),
                DropdownButton<bool?>(
                  value: _enabled,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Enabled: any')),
                    DropdownMenuItem(value: true, child: Text('true')),
                    DropdownMenuItem(value: false, child: Text('false')),
                  ],
                  onChanged: (v) {
                    setState(() => _enabled = v);
                  },
                ),
                FilledButton.tonal(
                  onPressed: _reload,
                  child: const Text('Qidirish'),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Darslik>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Xato: ${snap.error}'));
                }
                final items = (snap.data ?? <Darslik>[]);
                if (items.isEmpty) {
                  return const Center(child: Text('Ma’lumot yo‘q'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return ListTile(
                      title: Text('${it.title} (${it.code})'),
                      subtitle: Text('Enabled: ${it.enabled} • PDF: ${it.pdfPath}'),
                      onTap: () async {
                        await _openForm(item: it);
                        _reload();
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final ok = await _confirm(context, 'O‘chirilsinmi?');
                          if (ok != true) return;
                          try {
                            await app.service.darslikDelete(it.id!);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('O‘chirildi')));
                            _reload();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('Xato: $e')));
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
      FloatingActionButton(onPressed: () async { await _openForm(); _reload(); }, child: const Icon(Icons.add)),
    );
  }

  Future<void> _openForm({Darslik? item}) async {
    final app = context.read<AppState>();
    final code = TextEditingController(text: item?.code ?? '');
    final title = TextEditingController(text: item?.title ?? '');
    final text = TextEditingController(text: item?.text ?? '');
    final pdf = TextEditingController(text: item?.pdfPath ?? '');
    bool enabled = item?.enabled ?? true;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(item == null ? 'Darslik yaratish' : 'Darslik tahrirlash')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: code, decoration: const InputDecoration(labelText: 'Code (unique-like)')),
              const SizedBox(height: 8),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(
                controller: text,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Text'),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pdf,
                      decoration: const InputDecoration(labelText: 'PDF path (/static/...)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      try {
                        final res = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                          withData: true,
                        );
                        if (res == null || res.files.isEmpty) return;
                        final url = await app.service.uploadPdf(res.files.first);
                        pdf.text = url;
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF: $url')));
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload xato: $e')));
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                  ),
                ],
              ),

              SwitchListTile(
                title: const Text('Enabled'),
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
              ),
              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: () async {
                  try {
                    final model = Darslik(
                      id: item?.id,
                      code: code.text.trim(),
                      title: title.text.trim(),
                      text: text.text,
                      pdfPath: pdf.text.trim(),
                      enabled: enabled,
                    );
                    if (item == null) {
                      await app.service.darslikCreate(model);
                    } else {
                      await app.service.darslikUpdate(item.id!, model);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(item == null ? 'Yaratildi' : 'Yangilandi')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Saqlash'),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      try {
                        final c = code.text.trim();
                        if (c.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code kiriting')),
                          );
                          return;
                        }
                        final data = await app.service.darslikExportByCode(c);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Export: ${data['title'] ?? ''}')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export by code'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      try {
                        final c = code.text.trim();
                        if (c.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code kiriting')),
                          );
                          return;
                        }
                        final one = await app.service.darslikByCode(c);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('By code topildi: ${one.title}')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
                      }
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('By code'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    _reload();
  }

  Future<bool?> _confirm(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tasdiqlang'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Yo‘q')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ha')),
        ],
      ),
    );
  }
}
