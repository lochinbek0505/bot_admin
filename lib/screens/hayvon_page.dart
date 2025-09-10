import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';

class HayvonPage extends StatefulWidget {
  const HayvonPage({super.key});

  @override
  State<HayvonPage> createState() => _HayvonPageState();
}

class _HayvonPageState extends State<HayvonPage> {
  Future<List<HayvonItem>>? _future;
  bool? _enabled;
  HayGroup? _group;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().service;
    _future = s.hayvonList(enabled: _enabled, group: _group);
  }

  void _reload() {
    final s = context.read<AppState>().service;
    final f = s.hayvonList(enabled: _enabled, group: _group);
    setState(() {
      _future = f;
    });
  }

  Future<void> _refresh() async {
    final s = context.read<AppState>().service;
    final f = s.hayvonList(enabled: _enabled, group: _group);
    setState(() {
      _future = f;
    });
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<HayvonItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Xato: ${snap.error}'));
            }
            final items = (snap.data ?? <HayvonItem>[]);
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
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image_not_supported),
                  title: Text('${it.title} (${it.key})'),
                  subtitle: Text(
                    'Group: ${it.group.name} • Enabled: ${it.enabled} • Sort: ${it.sortOrder}',
                  ),
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
                        await app.service.hayvonDelete(it.id!);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('O‘chirildi')),
                        );
                        _reload();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Xato: $e')));
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
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const Text('Enabled:'),
            DropdownButton<bool?>(
              value: _enabled,
              items: const [
                DropdownMenuItem(value: null, child: Text('Hammasi')),
                DropdownMenuItem(value: true, child: Text('true')),
                DropdownMenuItem(value: false, child: Text('false')),
              ],
              onChanged: (v) {
                final s = context.read<AppState>().service;
                final f = s.hayvonList(enabled: v, group: _group);
                setState(() {
                  _enabled = v;
                  _future = f;
                });
              },
            ),
            const SizedBox(width: 12),
            const Text('Group:'),
            DropdownButton<HayGroup?>(
              value: _group,
              items: <DropdownMenuItem<HayGroup?>>[
                const DropdownMenuItem(value: null, child: Text('Hammasi')),
                ...HayGroup.values.map(
                  (g) => DropdownMenuItem(value: g, child: Text(g.name)),
                ),
              ],
              onChanged: (g) {
                final s = context.read<AppState>().service;
                final f = s.hayvonList(enabled: _enabled, group: g);
                setState(() {
                  _group = g;
                  _future = f;
                });
              },
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () async {
                await _openForm();
                _reload();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm({HayvonItem? item}) async {
    final app = context.read<AppState>();
    final keyCtrl = TextEditingController(text: item?.key ?? '');
    final titleCtrl = TextEditingController(text: item?.title ?? '');
    HayGroup group = item?.group ?? HayGroup.animal;
    final img = TextEditingController(text: item?.imagePath ?? '');
    final aud = TextEditingController(text: item?.audioPath ?? '');
    final sort = TextEditingController(text: (item?.sortOrder ?? 0).toString());
    bool enabled = item?.enabled ?? true;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(item == null ? 'Hayvon yaratish' : 'Hayvon tahrirlash'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Key (unique-like)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<HayGroup>(
                value: group,
                decoration: const InputDecoration(labelText: 'Group'),
                items: HayGroup.values
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                    .toList(),
                onChanged: (g) => setState(() {
                  if (g != null) group = g;
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: img,
                decoration: const InputDecoration(
                  labelText: 'Image path (/static/...)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: aud,
                decoration: const InputDecoration(
                  labelText: 'Audio path (/static/...)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sort,
                decoration: const InputDecoration(labelText: 'Sort order'),
                keyboardType: TextInputType.number,
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
                    final model = HayvonItem(
                      id: item?.id,
                      key: keyCtrl.text.trim(),
                      title: titleCtrl.text.trim(),
                      group: group,
                      imagePath: img.text.trim(),
                      audioPath: aud.text.trim(),
                      enabled: enabled,
                      sortOrder: int.tryParse(sort.text) ?? 0,
                    );
                    if (item == null) {
                      await app.service.hayvonCreate(model);
                    } else {
                      await app.service.hayvonUpdate(item.id!, model);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          item == null ? 'Yaratildi' : 'Yangilandi',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Xato: $e')));
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Saqlash'),
              ),
              const SizedBox(height: 16),
              if (img.text.isNotEmpty)
                Image.network(
                  app.toFullUrl(img.text),
                  height: 160,
                  fit: BoxFit.cover,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tasdiqlaysizmi?'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Yo‘q'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ha'),
          ),
        ],
      ),
    );
  }
}
