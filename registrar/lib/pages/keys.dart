import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registrar/providers.dart';

import '../crypto/schnorr.dart';

class KeysPage extends StatefulWidget {
  const KeysPage({Key? key}) : super(key: key);
  @override
  _KeysPageState createState() => _KeysPageState();
}

class _KeysPageState extends State<KeysPage> {
  BigInt _p = BigInt.zero;
  BigInt _q = BigInt.zero;
  BigInt _g = BigInt.zero;
  BigInt _yCounter = BigInt.zero;
  BigInt _x = BigInt.zero;
  BigInt _y = BigInt.zero;
  bool _saved = false;
  @override
  Widget build(BuildContext context) {
    final voterProvider = Provider.of<VoterProvider>(context);
    final keys = voterProvider.keys;
    final rsaKeys = voterProvider.rsaKeys;
    Map<String, String> schnorrMap = {
      'Простое число q': keys[0].toString(),
      'Простое число p, (p - 1) mod q = 0': keys[1].toString(),
      'Число g, g^q mod p = 1': keys[2].toString(),
      // 'Секретный ключ регистратора x, x ∈ {1, …, q-1}': keys[3].toString(),
      // 'Открытый ключ регистратора y, y = g^-x mod p': keys[4].toString(),
    };
    Map<String, String> rsaMap = {
      'Простое число p': rsaKeys[0].toString(),
      'Простое число q': rsaKeys[1].toString(),
      'Модуль n = p*q': rsaKeys[2].toString(),
      'Функция Эйлера φ(n) = (p-1) * (q-1)': rsaKeys[3].toString(),
      'Открытый ключ e': rsaKeys[4].toString(),
      'Закрытый ключ d': rsaKeys[5].toString(),
    };

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

    Future<void> saveData() async {
      _saved = false;
      const String fileName = 'registrarIdentity.json';
      final FileSaveLocation? result =
          await getSaveLocation(suggestedName: fileName);
      if (result == null) {
        return;
      }
      var identity = jsonEncode({
        'p': _p.toString(),
        'q': _q.toString(),
        'g': _g.toString(),
        'y': _y.toString(),
      });
      final Uint8List fileData = Uint8List.fromList(utf8.encode(identity));
      const String mimeType = 'text/plain';
      final XFile textFile =
          XFile.fromData(fileData, mimeType: mimeType, name: fileName);
      await textFile.saveTo(result.path);
      _saved = true;
    }

    void exportCounterDialog() {
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Аутентификация'),
              content: const Text(
                  'Сохраните данные для аутентификации и передайте их счётчику'),
              actions: <Widget>[
                ElevatedButton(
                    onPressed: () async {
                      await saveData();
                      if (_saved) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Сохранить данные')),
                ElevatedButton(
                  child: const Text('Отмена'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
      voterProvider.setCounterAuth(_q, _p, _g, _x, _y);
    }

    Future<void> importCounter() async {
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
          _p = BigInt.parse(json['p']);
          _q = BigInt.parse(json['q']);
          _g = BigInt.parse(json['g']);
          _yCounter = BigInt.parse(json['y']);
          List<BigInt> keys = Schnorr.genKeys(_p, _g, _q);
          _x = keys[0];
          _y = keys[1];
        } on FormatException catch (_) {
          fileError();
          return;
        }
      }
      exportCounterDialog();
    }

    Widget list(Map<String, String> map) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: map.length,
        itemBuilder: (BuildContext context, int index) {
          String title = map.keys.elementAt(index);
          String value = map.values.elementAt(index);
          return Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 5),
                TextField(
                  readOnly: true,
                  controller: TextEditingController(text: value),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('Ключи',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Expanded(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(children: [
                      const Text('Аутентификация по схеме Клауса Шнорра',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      list(schnorrMap),
                      const Text('Протокол RSA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      list(rsaMap)
                    ])))),
        ElevatedButton(
            onPressed: () async {
              await importCounter();
            },
            child: const Text('Импортировать данные счётчика')),
        const SizedBox(height: 10),
      ],
    );
  }
}
