// ignore_for_file: unused_field, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:counter/provider.dart';
import 'package:counter/server.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';

class IncorrectServerException implements Exception {
  String cause;
  IncorrectServerException(this.cause);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Счётчик');
    setWindowMinSize(const Size(1024, 768));
  }

  runApp(Counter());
}

class Counter extends StatelessWidget {
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
          home: const CounterPage(title: 'Регистратор'),
          debugShowCheckedModeBanner: false,
        ));
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key, required this.title});

  final String title;

  @override
  State<CounterPage> createState() => CounterState();
}

class CounterState extends State<CounterPage> {
  int authorizedVoters = 0;
  late Server _server;
  late Widget page;
  bool _saved = false;
  BigInt _y = BigInt.zero;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final voterProvider = Provider.of<VoterProvider>(context);

    void loadServer() async {
      await voterProvider.startServer(Provider.of<VoterProvider>(context));
    }

    Future<void> saveFile(keys) async {
      setState(() {
        _saved = false;
      });
      const String fileName = 'counterIdentity.json';
      final FileSaveLocation? result =
          await getSaveLocation(suggestedName: fileName);
      if (result == null) {
        return;
      }
      var identity = jsonEncode({
        'q': keys[0].toString(),
        'p': keys[1].toString(),
        'g': keys[2].toString(),
        'y': keys[4].toString(),
      });
      final Uint8List fileData = Uint8List.fromList(utf8.encode(identity));
      const String mimeType = 'text/plain';
      final XFile textFile =
          XFile.fromData(fileData, mimeType: mimeType, name: fileName);
      await textFile.saveTo(result.path);
      setState(() {
        _saved = true;
      });
    }

    void fileError() {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Ошибка'),
              content:
                  const Text('Файл повреждён или имеет недопустимый формат'),
              actions: <Widget>[
                ElevatedButton(
                  child: const Text('ОК'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
    }

    Widget importKey() {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Загрузите полученный от регистратора файл'),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () async {
                const XTypeGroup typeGroup = XTypeGroup(
                  label: 'Файл идентичности',
                  extensions: <String>['json'],
                );
                final XFile? file =
                    await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
                if (file == null) {
                  return;
                } else {
                  try {
                    var data = await file.readAsString();
                    var json = jsonDecode(data);
                    _y = BigInt.parse(json['y']);
                  } on FormatException catch (_) {
                    fileError();
                    return;
                  }
                  voterProvider.setPubkey(_y);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => VotePage()));
                }
              },
              child: const Text('Загрузить файл')),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  _saved = false;
                });
              },
              child: const Text('Назад'))
        ],
      ));
    }

    Widget exportKey() {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
              'Сохраните данные для аутентификации и передайте их регистратору'),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () async {
                await saveFile(voterProvider.keys);
              },
              child: const Text('Сохранить данные')),
          const SizedBox(height: 10),
          TextField(
              readOnly: true,
              controller:
                  TextEditingController(text: voterProvider.keys[0].toString()),
              decoration: const InputDecoration(
                  label: Text('Простое число q'),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ))),
          const SizedBox(height: 10),
          TextField(
              readOnly: true,
              controller:
                  TextEditingController(text: voterProvider.keys[1].toString()),
              decoration: const InputDecoration(
                  label: Text('Простое число p'),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ))),
          const SizedBox(height: 10),
          TextField(
              readOnly: true,
              controller:
                  TextEditingController(text: voterProvider.keys[2].toString()),
              decoration: const InputDecoration(
                  label: Text('Простое число g'),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ))),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () async {
                voterProvider.resetKeys();
              },
              child: const Text('Сброс'))
        ],
      ));
    }

    loadServer();
    return voterProvider.keys.isNotEmpty
        ? Scaffold(body: _saved ? importKey() : exportKey())
        : const Scaffold(
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                Text('Генерация ключей'),
                SizedBox(height: 10),
                CircularProgressIndicator()
              ])));
  }
}

class VotePage extends StatelessWidget {
  const VotePage({super.key});

  @override
  Widget build(BuildContext context) {
    final voterProvider = Provider.of<VoterProvider>(context);
    return voterProvider.voteStarted
        ? BulletinWidget()
        : Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Ожидание сообщения от регистратора'),
                  const SizedBox(height: 10),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: voterProvider.getPubKey().toString(),
                    ),
                    decoration: const InputDecoration(
                      label: Text('Открытый ключ регистратора y'),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}

class BulletinWidget extends StatefulWidget {
  @override
  _BulletinWidgetState createState() => _BulletinWidgetState();
}

class _BulletinWidgetState extends State<BulletinWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          "Голосование",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Expanded(
            child: SingleChildScrollView(
                child: Column(children: [
          Consumer<VoterProvider>(
            builder: (context, voterProvider, _) {
              final bulletin = voterProvider.bulletin;
              return (ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bulletin.length,
                itemBuilder: (context, index) {
                  final key = bulletin.keys.elementAt(index);
                  final values = bulletin[key];
                  var result = values?['result'];
                  var encKey = values?['key'];
                  var encBulletin = values?['bulletin'];
                  var signature = values?['signature'];
                  return ListTile(
                    title: Text(
                      'Избиратель с меткой $key',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(children: [
                      TextField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Зашифрованный бюллетень Ben',
                        ),
                        controller: TextEditingController(
                          text: encBulletin == null
                              ? 'Не проголосовал'
                              : encBulletin.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Ключ Ksec',
                        ),
                        controller: TextEditingController(
                          text:
                              encKey == null ? 'Нет ключа' : encKey.toString(),
                        ),
                      ),
                      TextField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Подпись DSen',
                        ),
                        controller: TextEditingController(
                          text: signature == null
                              ? 'Подпись не получена'
                              : signature.toString(),
                        ),
                      ),
                    ]),
                    trailing: result == null
                        ? const Text(
                            'н',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : Text(
                            result.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  );
                },
              ));
            },
          ),
        ]))),
        Consumer<VoterProvider>(
          builder: (context, voterProvider, _) {
            var minutes = voterProvider.remainingTime ~/ 60;
            var seconds = voterProvider.remainingTime % 60;

            return !voterProvider.voteEnded
                ? Text(
                    'Осталось времени: $minutes:${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ))
                : voterProvider.secondTour
                    ? const Text('Необходимо объявить второй тур')
                    : const Text('Голосование завершено');
          },
        ),
        const SizedBox(height: 10)
      ],
    ));
  }
}
