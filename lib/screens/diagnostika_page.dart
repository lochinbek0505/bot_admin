import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';

class DiagnostikaPage extends StatefulWidget {
  const DiagnostikaPage({super.key});
  @override
  State<DiagnostikaPage> createState() => _DiagnostikaPageState();
}

class _DiagnostikaPageState extends State<DiagnostikaPage> {
  Future<List<DiagnostikaItem>>? _future;
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    // initState ichida setState chaqirmaymiz; Future’ni bevosita tayinlash kifoya.
    final s = context.read<AppState>().service;
    _future = s.diagnostikaList(enabled: _enabled);
  }

  void _reload() {
    final s = context.read<AppState>().service;
    final f = s.diagnostikaList(enabled: _enabled);
    setState(() {
      _future = f; // setState faqat tayinlaydi, Future qaytarmaydi
    });
  }

  Future<void> _refresh() async {
    final s = context.read<AppState>().service;
    final f = s.diagnostikaList(enabled: _enabled);
    setState(() {
      _future = f;
    });
    await f; // RefreshIndicator to‘g‘ri yopilishi uchun
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DiagnostikaItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Xato: ${snap.error}'));
            }
            final items = (snap.data ?? <DiagnostikaItem>[]);
            if (items.isEmpty) {
              return const Center(child: Text('Ma’lumot yo‘q'));
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final it = items[i];
                return ListTile(
                  leading: it.imagePath.isNotEmpty
                      ? Image.network(
                    app.toFullUrl(it.imagePath),
                    width: 56, height: 56, fit: BoxFit.cover,
                  )
                      : const Icon(Icons.image_not_supported),
                  title: Text(it.phrase),
                  subtitle: Text('Enabled: ${it.enabled} • Sort: ${it.sortOrder}'),
                  onTap: () async {
                    await _openForm(item: it);
                    _reload(); // formdan qaytgach yangilab qo‘yamiz
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final ok = await _confirm(context, 'O‘chirilsinmi?');
                      if (ok != true) return;
                      try {
                        await app.service.diagnostikaDelete(it.id!);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('O‘chirildi')),
                        );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _openForm();
          _reload();
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: [
            const Text('Enabled filter:'),
            const SizedBox(width: 8),
            DropdownButton<bool?>(
              value: _enabled,
              items: const [
                DropdownMenuItem(value: null, child: Text('Hammasi')),
                DropdownMenuItem(value: true, child: Text('faqat true')),
                DropdownMenuItem(value: false, child: Text('faqat false')),
              ],
              onChanged: (v) {
                final s = context.read<AppState>().service;
                final f = s.diagnostikaList(enabled: v);
                setState(() {
                  _enabled = v;   // oddiy qiymat
                  _future = f;    // ready Future
                });
              },
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () async {
                try {
                  final data = await context.read<AppState>().service.diagnostikaExport();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export elementlari: ${data.length}')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm({DiagnostikaItem? item}) async {
    final app = context.read<AppState>();

    final phrase = TextEditingController(text: item?.phrase ?? '');
    final image  = TextEditingController(text: item?.imagePath ?? '');
    final sort   = TextEditingController(text: (item?.sortOrder ?? 0).toString());
    final enabled = ValueNotifier<bool>(item?.enabled ?? true);

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          title: Text(item == null ? 'Diagnostika yaratish' : 'Diagnostika tahrirlash'),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              final isCompact = w < 360;
              final gap = isCompact ? 8.0 : 12.0;
              final dense = isCompact;

              final content = ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  // Phrase
                  TextField(
                    controller: phrase,
                    decoration: InputDecoration(labelText: 'Phrase', isDense: dense),
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: gap),

                  // Image path (manual)
                  TextField(
                    controller: image,
                    decoration: InputDecoration(
                      labelText: 'Image path (/static/...)',
                      isDense: dense,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: gap),

                  // Upload row (wraps on small screens)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          try {
                            final res = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (res == null || res.files.isEmpty) return;

                            final url = await app.service.uploadImage(res.files.first); // /upload/image
                            image.text = url; // serverdagi nisbiy yo‘l

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Yuklandi: $url')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Upload xato: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.upload),
                        label: const Text('Rasm yuklash'),
                      ),
                      // Uploaded path preview (auto-updates)
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: image,
                        builder: (_, v, __) {
                          final t = v.text.trim();
                          if (t.isEmpty) return const SizedBox.shrink();
                          final short = t.length > 28 ? '${t.substring(0, 28)}…' : t;
                          return Text(
                            '(saqlanadi: $short)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: gap),

                  // Sort
                  TextField(
                    controller: sort,
                    decoration: InputDecoration(labelText: 'Sort order', isDense: dense),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                  ),

                  // Enabled (adaptive for iOS/Android)
                  ValueListenableBuilder<bool>(
                    valueListenable: enabled,
                    builder: (_, val, __) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enabled'),
                        value: val,
                        onChanged: (v) => enabled.value = v,
                      );
                    },
                  ),

                  SizedBox(height: gap * 1.5),

                  // Save button (full width on mobile)
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          final model = DiagnostikaItem(
                            id: item?.id,
                            phrase: phrase.text.trim(),
                            imagePath: image.text.trim(),
                            enabled: enabled.value,
                            sortOrder: int.tryParse(sort.text) ?? 0,
                          );
                          if (item == null) {
                            await app.service.diagnostikaCreate(model);
                          } else {
                            await app.service.diagnostikaUpdate(item.id!, model);
                          }
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(item == null ? 'Yaratildi' : 'Yangilandi')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Xato: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Saqlash'),
                    ),
                  ),

                  SizedBox(height: gap),

                  // Live image preview (auto updates with controller)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: image,
                    builder: (_, v, __) {
                      final t = v.text.trim();
                      if (t.isEmpty) return const SizedBox.shrink();
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            app.toFullUrl(t),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text('Rasmni yuklab bo‘lmadi'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );

              // Telefonlarda markazda va maksimal 560px kenglik bilan tutib turish
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: content,
                ),
              );
            },
          ),
        ),
      );
    }));
  }

  Future<bool?> _confirm(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tasdiqlaysizmi?'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Yo‘q')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ha')),
        ],
      ),
    );
  }
}
