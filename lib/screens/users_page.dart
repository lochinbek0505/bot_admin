import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  Future<List<BotUser>>? _future;
  bool? _blocked;
  String? _username;
  UserRole? _role;

  @override
  void initState() {
    super.initState();
    // initState ichida setState chaqirmaymiz
    final s = context.read<AppState>().service;
    _future = s.usersList(blocked: _blocked, username: _username, role: _role);
  }

  void _reload() {
    final s = context.read<AppState>().service;
    final f = s.usersList(blocked: _blocked, username: _username, role: _role);
    setState(() {
      _future = f; // callback hech narsa qaytarmaydi (void)
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // Filter panel: Wrap bilan, overflow bo‘lmaydi
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
                  decoration: const InputDecoration(labelText: 'Username filter'),
                  onChanged: (v) => _username = v.isEmpty ? null : v,
                ),
              ),
              DropdownButton<UserRole?>(
                value: _role,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Role: any')),
                  ...UserRole.values
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                      .toList(),
                ],
                onChanged: (v) {
                  setState(() {
                    _role = v;
                  });
                },
              ),
              DropdownButton<bool?>(
                value: _blocked,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Blocked: any')),
                  DropdownMenuItem(value: true, child: Text('true')),
                  DropdownMenuItem(value: false, child: Text('false')),
                ],
                onChanged: (v) {
                  setState(() {
                    _blocked = v;
                  });
                },
              ),
              FilledButton.tonal(onPressed: _reload, child: const Text('Qidirish')),
            ],
          ),
        ),

        Expanded(
          child: FutureBuilder<List<BotUser>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Xato: ${snap.error}'));
              }
              final items = (snap.data ?? <BotUser>[]);
              if (items.isEmpty) return const Center(child: Text('Ma’lumot yo‘q'));

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = items[i];
                  return ListTile(
                    title: Text('${u.tgId} • ${u.username ?? "-"}'),
                    subtitle: Text('Role: ${u.role.name} • Blocked: ${u.isBlocked} • ${u.fullName ?? ""}'),
                    onTap: () async {
                      await _openForm(user: u);
                      _reload();
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: u.isBlocked ? 'Unblock' : 'Block',
                          icon: Icon(u.isBlocked ? Icons.lock_open : Icons.lock),
                          onPressed: () async {
                            try {
                              final s = context.read<AppState>().service;
                              if (u.isBlocked) {
                                await s.userUnblock(u.id!);
                              } else {
                                await s.userBlock(u.id!);
                              }
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(content: Text('OK')));
                              _reload();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('Xato: $e')));
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final ok = await _confirm(context, 'O‘chirilsinmi?');
                            if (ok != true) return;
                            try {
                              await context.read<AppState>().service.userDelete(u.id!);
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
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
      floatingActionButton:
      FloatingActionButton(onPressed: () async { await _openForm(); _reload(); }, child: const Icon(Icons.add)),
    );
  }

  Future<void> _openForm({BotUser? user}) async {
    final app = context.read<AppState>();
    final tgId = TextEditingController(text: user?.tgId.toString() ?? '');
    final username = TextEditingController(text: user?.username ?? '');
    final fullName = TextEditingController(text: user?.fullName ?? '');
    final notes = TextEditingController(text: user?.notes ?? '');
    UserRole role = user?.role ?? UserRole.user;
    bool isBlocked = user?.isBlocked ?? false;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (ctx, setDlg) => Scaffold(
            appBar: AppBar(title: Text(user == null ? 'User yaratish' : 'User tahrirlash')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: tgId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'tg_id'),
                ),
                const SizedBox(height: 8),
                TextField(controller: username, decoration: const InputDecoration(labelText: 'username (optional)')),
                const SizedBox(height: 8),
                TextField(controller: fullName, decoration: const InputDecoration(labelText: 'full_name (optional)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  value: role,
                  items: UserRole.values
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                      .toList(),
                  onChanged: (v) => setDlg(() => role = v ?? role),
                  decoration: const InputDecoration(labelText: 'role'),
                ),
                const SizedBox(height: 8),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'notes (optional)')),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('is_blocked (faqat create/update JSON)'),
                  value: isBlocked,
                  onChanged: (v) => setDlg(() => isBlocked = v),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          if (user == null) {
                            final u = BotUser(
                              tgId: int.tryParse(tgId.text) ?? 0,
                              username: username.text.isEmpty ? null : username.text.trim(),
                              fullName: fullName.text.isEmpty ? null : fullName.text.trim(),
                              role: role,
                              isBlocked: isBlocked,
                              notes: notes.text.isEmpty ? null : notes.text.trim(),
                            );
                            await app.service.userCreate(u);
                          } else {
                            final u = BotUser(
                              id: user.id,
                              tgId: int.tryParse(tgId.text) ?? user.tgId,
                              username: username.text.isEmpty ? null : username.text.trim(),
                              fullName: fullName.text.isEmpty ? null : fullName.text.trim(),
                              role: role,
                              isBlocked: isBlocked,
                              notes: notes.text.isEmpty ? null : notes.text.trim(),
                            );
                            await app.service.userUpdate(user.id!, u);
                          }
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('OK')));
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Xato: $e')));
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save (POST/PUT)'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        try {
                          final up = await app.service.userUpsert(
                            tgId: int.tryParse(tgId.text) ?? 0,
                            username: username.text.isEmpty ? null : username.text.trim(),
                            fullName: fullName.text.isEmpty ? null : fullName.text.trim(),
                            role: role,
                            notes: notes.text.isEmpty ? null : notes.text.trim(),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Upsert OK: ${up.id}')));
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Xato: $e')));
                        }
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('Upsert (FormData)'),
                    ),
                  ],
                ),
              ],
            ),
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
