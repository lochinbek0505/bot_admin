import 'package:bot_admin_panel/screens/NotifyPage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_state.dart';
import 'screens/settings_screen.dart';
import 'screens/diagnostika_page.dart';
import 'screens/hayvon_page.dart';
import 'screens/darslik_page.dart';
import 'screens/users_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final ready = context.watch<AppState>().isReady;
    return MaterialApp(
      title: 'Admin Logosmart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF4C7DC6)),
      home: ready
          ? const HomeScreen()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Logosmart'),
        actions: [
          IconButton(
            tooltip: 'Health tekshirish',
            onPressed: () async {
              try {
                final h = await app.service.health();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Health: $h')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
              }
            },
            icon: const Icon(Icons.favorite),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: 'Diagnostika'),
            Tab(icon: Icon(Icons.headphones), text: 'Eshituv idroki'),
            Tab(icon: Icon(Icons.menu_book), text: 'Darsliklar'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.message), text: 'Xabarlar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          DiagnostikaPage(),
          HayvonPage(),
          DarslikPage(),
          UsersPage(),
          NotifyPage()
        ],
      ),
    );
  }
}
