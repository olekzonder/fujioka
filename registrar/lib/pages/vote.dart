import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../counter.dart';
import '../providers.dart';

class VotePage extends StatefulWidget {
  const VotePage({Key? key}) : super(key: key);

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  double _currentSliderValue = 5;
  String _counterIP =
      Platform.isWindows ? 'localhost:11102' : '127.0.0.1:11102';
  late Counter counter;
  @override
  Widget build(BuildContext context) {
    final voterProvider = Provider.of<VoterProvider>(context);
    counter = Counter(voterProvider);
    final bulletin = voterProvider.bulletin;
    Widget viewBulletin(context) {
      return const Align(
          alignment: Alignment.center, child: Text('Голосование начато'));
    }

    Widget emptyList(context) {
      return const Align(
          alignment: Alignment.center,
          child:
              Text('Для того, чтобы начать голосование, утвердите бюллетень'));
    }

    void showError(context, text) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Ошибка'),
              content: Text(text),
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

    void successDialog(context) async {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: const Text('Соединение успешно установлено!'),
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

    void testDialog(context) async {
      counter.setIP(_counterIP);
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Подключение к серверу',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  SizedBox(height: 10),
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Пожалуйста, подождите')
                ],
              );
            }));
          });
      await counter.testCounter();
      Navigator.of(context).pop();
      if (counter.counterErr != '') {
        showError(context, counter.counterErr);
      } else {
        successDialog(context);
      }
    }

    void connectionDialog(context) async {
      counter.setIP(_counterIP);
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Подключение к серверу',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  SizedBox(height: 10),
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Пожалуйста, подождите')
                ],
              );
            }));
          });
      await counter.testCounter();
      if (counter.counterErr != '') {
        Navigator.of(context).pop();
        showError(context, counter.counterErr);
      } else {
        if (voterProvider.authKeys.isEmpty) {
          Navigator.of(context).pop();
          showError(context, 'Загрузите ключи аутентификации');
        } else {
          await counter.connectCounter();
          counter.startLogin(voterProvider.authKeys);
          await for (bool authed in counter.sendStreamer.stream) {
            if (authed) {
              await voterProvider.startVote();
              break;
            } else {
              Navigator.of(context).pop();
              showError(context, 'Аутентификация не удалась');
              return;
            }
          }
          Navigator.of(context).pop();
          counter.startVote(_currentSliderValue.round());
        }
      }
    }

    voteStartDialog(context) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Параметры голосования'),
              content: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Время на голосование (минут)'),
                    Slider(
                      value: _currentSliderValue,
                      max: 15,
                      min: 1,
                      divisions: 14,
                      label: _currentSliderValue.round().toString(),
                      onChanged: (double value) {
                        setState(() {
                          _currentSliderValue = value;
                        });
                      },
                    ),
                    const Text('Адрес счётчика (IP-адрес: порт)'),
                    TextFormField(
                      initialValue: _counterIP,
                      onChanged: (value) {
                        _counterIP = value;
                      },
                    ),
                  ],
                );
              }),
              actions: <Widget>[
                ElevatedButton(
                    onPressed: () async {
                      testDialog(context);
                    },
                    child: const Text('Проверить соединение с счётчиком')),
                ElevatedButton(
                  child: const Text('Начать голосование'),
                  onPressed: () {
                    connectionDialog(context);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
    }

    Widget buttons(context) {
      return Align(
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () {
                if (voterProvider.voters.length < 2) {
                  showError(context,
                      'Для начала голосования необходимо как минимум два избирателя');
                } else {
                  voteStartDialog(context);
                }
              },
              child: const Text('Начать голосование'))
        ]),
      );
    }

    if (bulletin.isEmpty) {
      return emptyList(context);
    }
    if (!voterProvider.voteStarted) {
      return buttons(context);
    } else {
      return viewBulletin(context);
    }
  }
}
