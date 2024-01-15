// ignore_for_file: unused_field

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registrar/pages/bulletin.dart';
import 'package:registrar/pages/database.dart';
import 'package:registrar/pages/vote.dart';
import 'package:registrar/pages/keys.dart';
import 'package:registrar/providers.dart';
import 'package:window_size/window_size.dart';

class IncorrectServerException implements Exception {
  String cause;
  IncorrectServerException(this.cause);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Регистратор');
    setWindowMinSize(const Size(1024, 768));
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => VoterProvider()),
        ],
        child: MaterialApp(
          title: 'Регистратор',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                brightness: Brightness.dark, seedColor: Colors.blue),
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: const RegistrarPage(title: 'Регистратор'),
          debugShowCheckedModeBanner: false,
        ));
  }
}

class RegistrarPage extends StatefulWidget {
  const RegistrarPage({super.key, required this.title});

  final String title;

  @override
  State<RegistrarPage> createState() => RegistrarState();
}

class RegistrarState extends State<RegistrarPage> {
  late String _counterErr;
  late final Widget _bulletinPage;
  late final Widget _databasePage;
  late final Widget _votePage;
  late final Widget _keysPage;
  int _selectedIndex = 0;
  late final VoterProvider _voterProvider;
  @override
  void initState() {
    super.initState();
    _bulletinPage = const BulletinPage();
    _databasePage = const DatabasePage();
    _keysPage = const KeysPage();
    _votePage = const VotePage();
  }

  @override
  Widget build(BuildContext context) {
    final voterProvider = Provider.of<VoterProvider>(context);

    void loadServer() async {
      await voterProvider.startServer();
    }

    loadServer();
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = _bulletinPage;
        break;
      case 1:
        page = _keysPage;
        break;
      case 2:
        page = _databasePage;
        break;
      case 3:
        page = _votePage;
      default:
        throw UnimplementedError('Нет такого пункта меню');
    }
    return voterProvider.keys.isNotEmpty && voterProvider.rsaKeys.isNotEmpty
        ? Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    extended: true,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.ballot),
                        label: Text('Бюллетень'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.key),
                        label: Text('Ключи'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.people),
                        label: Text('БД избирателей'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.check),
                        label: Text('Голосование'),
                      ),
                    ],
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (value) {
                      setState(() {
                        _selectedIndex = value;
                      });
                    },
                  ),
                ),
                const VerticalDivider(thickness: 2),
                Expanded(child: page),
              ],
            ),
          )
        : const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
