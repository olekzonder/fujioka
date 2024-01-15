// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:voter/gost.dart';
import 'package:voter/log.dart';
import 'package:voter/prime.dart';
import 'package:voter/random.dart';
import 'package:voter/schnorr.dart';
import 'dart:io';
import 'package:window_size/window_size.dart';
import 'package:logging/logging.dart';

import 'rsa.dart';

class IncorrectServerException implements Exception {
  String cause;
  IncorrectServerException(this.cause);
}

class Stop {}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Избиратель');
    setWindowMinSize(const Size(1024, 768));
  }

  runApp(const Voter());
}

class Voter extends StatelessWidget {
  const Voter({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Аутентификация методом Клауса Шнорра',
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
      home: const VoterApp(title: 'Аутентификация методом Клауса Шнорра'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VoterApp extends StatefulWidget {
  const VoterApp({super.key, required this.title});

  final String title;

  @override
  State<VoterApp> createState() => SchnorrState();
}

class SchnorrState extends State<VoterApp> {
  BigInt _q = BigInt.zero;
  BigInt _p = BigInt.zero;
  BigInt _g = BigInt.zero;
  BigInt _x = BigInt.zero;
  BigInt _y = BigInt.zero;
  BigInt _v = BigInt.zero;
  BigInt _V = BigInt.zero;
  BigInt _c = BigInt.zero;
  BigInt _r = BigInt.zero;
  BigInt _code = BigInt.zero;

  BigInt _yServer = BigInt.zero;
  String _fio = '';
  BigInt code = BigInt.zero;
  bool _ver = false;
  bool _authenticated = false;
  bool _cantRegister = false;
  int _selectedIndex = 0;
  int _regPhase = -1;
  int _loginPhase = -1;
  int _loginError = 0;
  String _ipReg = Platform.isWindows ? 'localhost:11101' : '127.0.0.1:11101';
  String _ipCounter =
      Platform.isWindows ? 'localhost:11102' : '127.0.0.1:11102';
  String _resultString = '';
  var _socketReg;
  var _socketCounter;

  int _testedReg = -1;
  int _testedCounter = -1;
  int _resViewMode = 1;
  bool _counterConnected = false;
  String _regErr = '';
  String _counterErr = '';
  Map<int, String> _bulletin = {};
  Map<String, Map<String, String>> _voters = {};
  Map<String, int> _results = {};
  String _title = '';
  int _selectedItem = -1;
  bool _voted = false;
  StreamController<dynamic> _regStreamController =
      StreamController<dynamic>.broadcast();
  StreamController<dynamic> _counterStreamController =
      StreamController<dynamic>.broadcast();
  Kuznechik kuznechik = Kuznechik();
  BigInt kuzKey = BigInt.zero;
  List<BigInt> roundKeys = [];
  BigInt m = BigInt.zero;
  BigInt _bulletinVote = BigInt.zero;
  BigInt encryptedBulletin = BigInt.zero;

  BigInt _n = BigInt.zero;
  BigInt _e = BigInt.zero;
  BigInt _rand = BigInt.zero;
  BigInt _blind = BigInt.zero;
  BigInt _signed = BigInt.zero;
  BigInt _unblind = BigInt.zero;
  int _totalVoters = 0;
  int _votedVoters = 0;

  bool _sentKey = false;

  String _stringResult = '';
  Future<void> _testReg() async {
    try {
      final _socketCounter = await WebSocket.connect('ws://$_ipReg');
      Log().log('Успешно подключился к серверу');
      await for (var message in _socketCounter) {
        if (message == 'registrar') {
          Log().log('Сервер является регистратором');
          break;
        } else {
          throw IncorrectServerException('Сервер не является регистратором');
        }
      }
      setState(() {
        _testedReg = 1;
      });
      _socketCounter.close();
    } on SocketException catch (e) {
      setState(() {
        _testedReg = 0;
        _regErr = e.message;
      });
    } on WebSocketException catch (e) {
      setState(() {
        _testedReg = 0;
        _regErr = e.message;
      });
    } on ArgumentError catch (e) {
      setState(() {
        _testedReg = 0;
        _regErr = e.message;
      });
    } on IncorrectServerException catch (e) {
      setState(() {
        _testedReg = 0;
        _regErr = e.cause;
      });
    } on HttpException catch (e) {
      setState(() {
        _testedReg = 0;
        _regErr = e.message;
      });
    }
  }

  Future<void> _testCounter() async {
    try {
      _socketCounter = await WebSocket.connect('ws://$_ipCounter');
      Log().log('Подключен к серверу');
      await for (var message in _socketCounter) {
        if (message == 'counter') {
          break;
        } else {
          throw IncorrectServerException('Сервер не является счётчиком');
        }
      }
      setState(() {
        _testedCounter = 1;
      });
      _socketCounter.close();
    } on SocketException catch (e) {
      setState(() {
        _testedCounter = 0;
        _counterErr = e.message;
      });
    } on WebSocketException catch (e) {
      setState(() {
        _testedCounter = 0;
        _counterErr = e.message;
      });
    } on ArgumentError catch (e) {
      setState(() {
        _testedReg = 0;
        _counterErr = e.message;
      });
    } on IncorrectServerException catch (e) {
      setState(() {
        _testedCounter = 0;
        _counterErr = e.cause;
      });
    } on HttpException catch (e) {
      setState(() {
        _testedCounter = 0;
        _counterErr = e.message;
      });
    }
  }

  Future<void> _connectReg() async {
    try {
      _socketReg = await WebSocket.connect('ws://$_ipReg');
      _socketReg.listen((data) {
        Log().log('Получено сообщение от регистратора: $data');
        if (data != 'registrar') {
          _regStreamController.add(data);
        }
      }, onDone: () {
        Log().log('Соединение с регистратором закрыто');
        _regStreamController.close();
        resetValues();
        setState(() {});
      }, onError: (error) {
        Log().log('Ошибка: $error');
        _regStreamController.close();
        resetValues();
      });

      Log().log('Подключен к регистратору');
    } catch (e) {
      Log().log('Не удалось подключиться к регистратору: $e');
    }
  }

  Future<void> _connectCounter() async {
    try {
      _counterStreamController = StreamController<dynamic>.broadcast();
      _socketCounter = await WebSocket.connect('ws://$_ipCounter');
      _socketCounter.listen((data) {
        Log().log('Получено сообщение от счётчика: $data');
        if (data != 'counter') {
          _counterStreamController.add(data);
          setState(() {
            _counterConnected = true;
          });
        }
      }, onDone: () {
        Log().log('Соединение с счётчиком закрыто');
        _counterStreamController.close();

        setState(() {});
      }, onError: (error) {
        Log().log('Error: $error');
        _counterStreamController.close();
        setState(() {
          _counterConnected = false;
        });
      });

      Log().log('Подключен к счётчику');
    } catch (e) {
      Log().log('Не удалось подключиться к счётчику: $e');
    }
  }

  void resetValues() {
    setState(() {
      _q = BigInt.zero;
      _p = BigInt.zero;
      _g = BigInt.zero;
      _x = BigInt.zero;
      _y = BigInt.zero;
      _v = BigInt.zero;
      _V = BigInt.zero;
      _c = BigInt.zero;
      _r = BigInt.zero;
      _n = BigInt.zero;
      _e = BigInt.zero;
      _code = BigInt.zero;
      _ver = false;
      _authenticated = false;
      _cantRegister = false;
      _testedReg = -1;
      _bulletin = {};
      _title = '';
      _regStreamController = StreamController<dynamic>.broadcast();
      _selectedIndex = 0;
      kuzKey = BigInt.zero;
      roundKeys = [];
      _bulletinVote = BigInt.zero;
      _results = {};
      _voters = {};
      encryptedBulletin = BigInt.zero;
      _voted = false;
      _n = BigInt.zero;
      _e = BigInt.zero;
      _rand = BigInt.zero;
      _blind = BigInt.zero;
      _signed = BigInt.zero;
      _unblind = BigInt.zero;
      _counterConnected = false;
    });
  }

  void _testRegDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _testedReg == 0
                      ? Column(children: [
                          const Text('Ошибка при соединении c регистратором',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 20)),
                          const SizedBox(height: 10),
                          Text(_regErr)
                        ])
                      : const Column(children: [
                          Text('Проверка соединения с регистратором',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 20)),
                          SizedBox(height: 10),
                          Text('Соединение успешно установлено!')
                        ])
                ],
              );
            }),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('ОК'))
            ],
          );
        });
  }

  Future<void> _connectCounterDialog(BuildContext context) async {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Подключение к счётчику',
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
    await _connectCounter();
    Navigator.of(context).pop();
  }

  Future<void> _buildTestRegLoadingDialog(BuildContext context) async {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Подключение к регистратору',
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
    await _testReg();
    Navigator.of(context).pop();
  }

  void _testCounterDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _testedCounter == 0
                      ? Column(children: [
                          const Text('Ошибка при соединении c счётчиком',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 20)),
                          const SizedBox(height: 10),
                          Text(_counterErr)
                        ])
                      : const Text('Соединение успешно установлено!')
                ],
              );
            }),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('ОК'))
            ],
          );
        });
  }

  Future<void> _buildTestCounterLoadingDialog(BuildContext context) async {
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
    await _testCounter();
    Navigator.of(context).pop();
  }

  Widget _authpage(BuildContext context) {
    return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _authenticated == true && _ver == true
                ? [
                    Text('Вы подключены к регистратору как $_fio'),
                    // const SizedBox(height: 10),
                    // ElevatedButton(
                    //     onPressed: () {
                    //       _socketReg.close();
                    //       _regStreamController.close();
                    //       resetValues();
                    //     },
                    //     child: const Text('Отключиться'))
                  ]
                : [
                    ElevatedButton(
                      onPressed: () {
                        _showRegistrationDialog(context);
                      },
                      child: const Text('Регистрация'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        _loginDialog(context);
                      },
                      child: const Text('Вход'),
                    ),
                  ],
          ),
        ),
      );
    });
  }

  Future<void> _buildAuthDialog(BuildContext context) async {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Аутентификация',
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
    await _connectReg();
    Navigator.of(context).pop();
    _regStreamController.add(Stop());
    _listenReg();
    _startLogin();
    setState(() {});
  }

  Future<void> _buildRegDialog(BuildContext context) async {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Регистрация',
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
    await _connectReg();
    Navigator.of(context).pop();
    _regStreamController.add(Stop());
    _listenReg();
    _startRegister();
    setState(() {});
  }

  Future<void> _listenReg() async {
    await for (var message in _regStreamController.stream) {
      if (message.runtimeType == Stop) {
        return;
      }
      if (_regPhase > -1) {
        _register(message);
      } else if (_loginPhase > -1) {
        _login(message);
      } else {
        handleRegMessage(message);
      }
    }
  }

  void handleRegMessage(message) {
    late var parsedMessage;
    try {
      parsedMessage = jsonDecode(message);
    } catch (_) {
      return;
    }
    switch (parsedMessage['type']) {
      case 'bulletin':
        setState(() {
          _voted = false;
          _sentKey = false;
        });
        Log().log('Получен бюллетень, начинаю голосование');
        setState(() {
          _title = parsedMessage['0'];
          parsedMessage.forEach((key, value) {
            if (key != '0' && key != 'code' && key != 'type') {
              _bulletin[int.parse(key)] = value;
            }
          });
          _selectedIndex = 2;
        });
        break;
      case 'sign':
        setState(() {
          _signed = BigInt.parse(parsedMessage['bulletin']);
          _unblind = RSA.unblind(_signed, _n, _rand);
        });
        Navigator.of(context).pop();
        _counterStreamController.add(Stop());
        _listenCounter();

        setState(() {
          _voted = true;
        });

        _socketCounter.add(jsonEncode({
          'type': 'castVote',
          'id': _code.toString(),
          'bulletin': encryptedBulletin.toString(),
          'signature': _unblind.toString()
        }));
        break;
      case 'alreadyVoted':
        Log().log('Пользователь уже голосовал');
        Navigator.of(context).pop();
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Ошибка'),
                content: const Text('Вы уже голосовали'),
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
  }

  Future<void> _startRegister() async {
    _q = BigInt.zero;
    _p = BigInt.zero;
    _g = BigInt.zero;
    _x = BigInt.zero;
    _y = BigInt.zero;
    _v = BigInt.zero;
    _V = BigInt.zero;
    _c = BigInt.zero;
    _r = BigInt.zero;
    _code = BigInt.zero;
    _ver = false;
    _authenticated = false;
    _cantRegister = false;
    _testedReg = -1;
    _bulletin = {};
    _title = '';
    _regPhase = 0;
    _socketReg.add('register');
  }

  Future<void> _register(String message) async {
    Log().log('Текущая фаза регистрации: $_regPhase');
    switch (_regPhase) {
      case 0:
        if (message.toString() == 'Forbidden') {
          _ver = false;
          _authenticated = false;
          _cantRegister = true;
          _regPhase = -1;
          Log().log('Регистрация запрещена');
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Ошибка'),
                  content: const Text('Регистрация заблокирована'),
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
        } else {
          var msg = jsonDecode(message);
          _q = BigInt.parse(msg['q']);
          _p = BigInt.parse(msg['p']);
          _g = BigInt.parse(msg['g']);
          _yServer = BigInt.parse(msg['y']);
          var keys = Schnorr.genKeys(_p, _q, _g);
          _x = keys[0];
          _y = keys[1];
          _v = Schnorr.genV(_q, _p);
          _V = Schnorr.genVCap(_q, _p, _g, _v);
          String output =
              jsonEncode({'y': _y.toString(), 'V': _V.toString(), 'fio': _fio});
          _socketReg.add(output);
          _regPhase++;
        }
        break;
      case 1:
        _c = BigInt.parse(message.toString());
        _r = Schnorr.computeChallenge(_v, _x, _c, _q);
        _socketReg.add(jsonEncode({'r': _r.toString()}));
        _regPhase++;
        break;
      case 2:
        if (message != '0') {
          setState(() {
            Log().log('Успешная аутентификация');
            _authenticated = true;
            _ver = true;
            _selectedIndex = 1;
            _regPhase = -1;
            var parsedMessage = jsonDecode(message);
            _n = BigInt.parse(parsedMessage['n']);
            _e = BigInt.parse(parsedMessage['e']);
          });
        } else {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Ошибка'),
                  content: const Text(
                      'Аутентификация не удалась. Обратитесь к регистратору.'),
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
          Log().log('Аутентификация не удалась');
          setState(() {
            _authenticated = true;
            _ver = false;
            _selectedIndex = 1;
            _regPhase = -1;
          });
        }
        break;
      default:
        break;
    }
  }

  Future<void> _startLogin() async {
    setState(() {
      _loginPhase = 0;
      _authenticated = false;
      _loginError = 0;
    });
    _socketReg.add('login');
  }

  Future<void> _login(String message) async {
    Log().log('Текущая фаза аутентификации: $_loginPhase');
    switch (_loginPhase) {
      case 0:
        var msg = jsonDecode(message);
        _q = BigInt.parse(msg['q']);
        _p = BigInt.parse(msg['p']);
        _g = BigInt.parse(msg['g']);
        _yServer = BigInt.parse(msg['y']);
        _v = Schnorr.genV(_q, _p);
        _V = Schnorr.genVCap(_q, _p, _g, _v);
        String output = jsonEncode({'y': _y.toString(), 'V': _V.toString()});
        _socketReg.add(output);
        _loginPhase++;
        break;
      case 1:
        if (message == 'User was not found in the database') {
          setState(() {
            _loginError = 1;
            _loginPhase = -1;
          });
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Ошибка'),
                  content: const Text(
                      'Пользователь не был найден в базе данных регистратора'),
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
          break;
        }
        var msg = jsonDecode(message);
        _c = BigInt.parse(msg['c'].toString());
        _fio = msg['fio'].toString();
        _r = Schnorr.computeChallenge(_v, _x, _c, _q);
        _socketReg.add(jsonEncode({'r': _r.toString()}));
        _loginPhase++;
        break;
      case 2:
        if (message != '0') {
          setState(() {
            Log().log('Аутентификация успешна');
            var parsedMessage = jsonDecode(message);
            _n = BigInt.parse(parsedMessage['n']);
            _e = BigInt.parse(parsedMessage['e']);
            Log().log('Получены ключи RSA от регистратора');
            Log().log('Модуль n: $_n');
            Log().log('Публичный ключ e: $_e');
            _authenticated = true;
            _ver = true;
            _selectedIndex = 1;
            _loginPhase = -1;
          });
        } else {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Ошибка'),
                  content: const Text(
                      'Аутентификация не удалась. Обратитесь к регистратору.'),
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
          Log().log('Аутентификация не удалась');
          setState(() {
            _authenticated = true;
            _ver = false;
            _selectedIndex = 1;
            _loginPhase = -1;
          });
        }
        break;
      default:
        break;
    }
  }

  void fileError(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Ошибка'),
            content: const Text('Файл повреждён или имеет недопустимый формат'),
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

  void _loginDialog(BuildContext context) async {
    resetValues();
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
        _fio = json['fio'];
        _x = BigInt.parse(json['x']);
        _y = BigInt.parse(json['y']);
      } catch (_) {
        fileError(context);
        return;
      }
      await _buildTestRegLoadingDialog(context);
      if (_testedReg == 0) {
        _testRegDialog(context);
      } else {
        await _buildAuthDialog(context);
      }
    }
  }

  void _showRegistrationDialog(BuildContext context) {
    _fio = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Регистрация'),
          content: TextField(
            onChanged: (value) {
              _fio = value;
            },
            decoration: const InputDecoration(
              labelText: 'Введите ФИО',
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () async {
                if (_fio == '') {
                  null;
                } else {
                  await _buildTestRegLoadingDialog(context);
                  if (_testedReg == 0) {
                    _testRegDialog(context);
                  } else {
                    _buildRegDialog(context);
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Зарегистрироваться'),
            ),
          ],
        );
      },
    );
  }

  Widget _keyPage(BuildContext context) {
    Map<String, String> variables = {
      'Простое число q': _q.toString(),
      'Простое число p, (p - 1) mod q = 0': _p.toString(),
      'Число g, g^q mod p = 1': _g.toString(),
      'Секретный ключ x, x ∈ {1, …, q-1}': _x.toString(),
      'Открытый ключ y, y = g^-x mod p': _y.toString(),
      'Случайное значение k, сгенерированное избирателем, k ∈ {1, …, q-1}':
          _v.toString(),
      'Значение r, r = g^k mod p': _V.toString(),
      'Случайное значение e, полученное от регистратора, e ∈ {1, …, q-1}':
          _c.toString(),
      'Вычисленное на стороне избирателя значение s, s = (k+xe) mod q':
          _r.toString(),
    };

    Map<String, String> rsaKeys = {
      'Модуль n = p*q': _n.toString(),
      'Публичный ключ e': _e.toString(),
    };

    return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
      return Scaffold(
          body: Center(
              child: _authenticated
                  ? Column(children: [
                      const SizedBox(height: 10),
                      const Text('Ключи',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: <Widget>[
                              Column(
                                children: [
                                  const SizedBox(height: 10),
                                  const Text(
                                      'Аутентификация по схеме Клауса Шнорра',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: variables.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      String title =
                                          variables.keys.elementAt(index);
                                      String value =
                                          variables.values.elementAt(index);
                                      return Container(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              controller: TextEditingController(
                                                  text: value),
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const Text('Протокол RSA',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: rsaKeys.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      String title =
                                          rsaKeys.keys.elementAt(index);
                                      String value =
                                          rsaKeys.values.elementAt(index);
                                      return Container(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              controller: TextEditingController(
                                                  text: value),
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      ElevatedButton(
                          onPressed: () {
                            _saveIdentity();
                          },
                          child: const Text(
                              'Сохранить данные для аутентификаиции')),
                      const SizedBox(height: 10)
                    ])
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Text('Аутентифицируйтесь для просмотра данных')
                        ])));
    });
  }

  void _saveIdentity() async {
    const String fileName = 'identity.json';
    final FileSaveLocation? result =
        await getSaveLocation(suggestedName: fileName);
    if (result == null) {
      return;
    }
    var identity =
        jsonEncode({'fio': _fio, 'y': _y.toString(), 'x': _x.toString()});
    final Uint8List fileData = Uint8List.fromList(utf8.encode(identity));
    const String mimeType = 'text/plain';
    final XFile textFile =
        XFile.fromData(fileData, mimeType: mimeType, name: fileName);
    await textFile.saveTo(result.path);
  }

  Widget _votePage(BuildContext context) {
    Widget awaitAuth(BuildContext context) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Для начала работы необходимо аутентифицироваться'),
        ],
      );
    }

    Widget awaitBulletin(BuildContext) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 10),
          Text('Ожидание начала голосования'),
        ],
      );
    }

    Widget bulletinForm(BuildContext context) {
      return Column(
        children: [
          Text(
            _title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _bulletin.entries.map((entry) {
                  int bulletinChoice = entry.key;
                  String bulletinString = entry.value;
                  return RadioListTile(
                    title: Text(
                      bulletinString,
                    ),
                    value: bulletinChoice,
                    groupValue: _selectedItem,
                    onChanged: (value) {
                      setState(() {
                        if (_voted) {
                          null;
                        } else {
                          _selectedItem = value!;
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                children: [
                  ButtonBar(alignment: MainAxisAlignment.center, children: [
                    _voted
                        ? Text('Метка: $_code')
                        : ElevatedButton(
                            onPressed: () async {
                              if (_selectedItem == -1) {
                                null;
                              } else {
                                _code = KuznechikRand().generateRandomBytes(8);
                                _bulletinVote =
                                    BigInt.parse(_selectedItem.toString());
                                await _voteCounterDialog(context);
                                _signDialog();
                              }
                            },
                            child: const Text('Проголосовать')),
                  ])
                ],
              ))
        ],
      );
    }

    Widget getWidget(BuildContext context) {
      if (!(_authenticated)) {
        return awaitAuth(context);
      }
      if (_bulletin.isEmpty) {
        return awaitBulletin(context);
      }
      return bulletinForm(context);
    }

    return Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: getWidget(context),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _resultPage(BuildContext context) {
    Widget getVoters() {
      return Column(children: [
        const Text(
          'Реестр учтённых голосов',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Expanded(
            child: _voters.isEmpty
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text('Пока никто не проголовал')])
                : SingleChildScrollView(
                    child: Column(children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _voters.length,
                      itemBuilder: (context, index) {
                        final key = _voters.keys.elementAt(index);
                        final value = _voters[key];
                        final bulletin = value!['bulletin'];
                        final signature = value!['signature'];
                        final encKey = value!['key'];
                        final decrypt = value!['unencrypted'];
                        return ListTile(
                            title: Text(
                              'Избиратель с меткой $key',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: TextField(
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Зашифрованный бюллетень Ben',
                                        ),
                                        controller: TextEditingController(
                                          text: bulletin.toString(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: TextField(
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Подписанный бюллетень DSen',
                                        ),
                                        controller: TextEditingController(
                                          text: signature == null
                                              ? 'Ожидание окончания голосования'
                                              : signature.toString(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: TextField(
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Ключ шифрования ksecr',
                                        ),
                                        controller: TextEditingController(
                                          text: encKey == null
                                              ? 'Ожидание окончания голосования'
                                              : encKey.toString(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: TextField(
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Расшифрованный бюллетень B',
                                        ),
                                        controller: TextEditingController(
                                          text: decrypt == null
                                              ? 'Ожидание окончания голосования'
                                              : decrypt.toString(),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ));
                      },
                    )
                  ]))),
        ElevatedButton(
            onPressed: () {
              setState(() {
                _resViewMode = 1;
              });
            },
            child: const Text('Показать результаты голосования'))
      ]);
    }

    Widget getResults() {
      return Column(
        children: [
          Text(
            _title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Expanded(
              child: _results.isEmpty
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Text('Дождитесь окончания голосования')])
                  : SingleChildScrollView(
                      child: Column(children: [
                      ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final key = _results.keys.elementAt(index);
                            final value = _results.values.elementAt(index);
                            double percentage = (value / _votedVoters);
                            return ListTile(
                              title: Text(key),
                              subtitle: Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: percentage,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.blue),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$value (${(percentage * 100).toStringAsFixed(2)}%)',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          }),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_resultString,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ))
                          ]),
                      Text('Всего проголосовало: $_votedVoters'),
                      Text('Легитимных избирателей: $_totalVoters'),
                      Text(
                          'Явка: ${((_votedVoters / _totalVoters) * 100).toStringAsFixed(2)}%'),
                    ]))),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  _resViewMode = 0;
                });
              },
              child: const Text('Показать учтённые голоса'))
        ],
      );
    }

    Widget getWidget() {
      if (_counterConnected) {
        switch (_resViewMode) {
          case 0:
            return getVoters();
          case 1:
            return getResults();
          default:
            break;
        }
      }
      return const Text('Нет подключения к счётчику');
    }

    return Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: getWidget(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _settingsPage(BuildContext context) {
    return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
      return Scaffold(
          body: Center(
              child: Column(children: [
        _authenticated
            ? TextFormField(
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Адрес регистратора (IP-адрес:порт).',
                ),
                initialValue: _ipReg,
                readOnly: true,
                onChanged: (value) {
                  _ipReg = value;
                },
              )
            : TextFormField(
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Адрес регистратора (IP-адрес:порт).',
                ),
                initialValue: _ipReg,
                onChanged: (value) {
                  _ipReg = value;
                },
              ),
        TextFormField(
          decoration: const InputDecoration(
            border: UnderlineInputBorder(),
            labelText: 'Адрес счётчика (IP-адрес:порт).',
          ),
          initialValue: _ipCounter,
          onChanged: (value) {
            _ipCounter = value;
          },
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
                onPressed: () async {
                  await _buildTestRegLoadingDialog(context);
                  _testRegDialog(context);
                },
                child: const Text('Проверить соединение с регистратором')),
            const SizedBox(
              width: 10,
            ),
            ElevatedButton(
                onPressed: () async {
                  await _buildTestCounterLoadingDialog(context);
                  _testCounterDialog(context);
                },
                child: const Text('Проверить соединение с счётчиком')),
          ],
        ),
      ])));
    });
  }

  Widget _cryptoPage(BuildContext context) {
    return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
      return Scaffold(
          body: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
            _voted
                ? Expanded(
                    child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        Column(
                          children: [
                            const SizedBox(height: 10),
                            const Text('Шифрование ГОСТ Р.34-12 «Кузнечик»',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 20)),
                            Container(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Бюллетень B',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextField(
                                    readOnly: true,
                                    controller: TextEditingController(
                                        text: _bulletinVote.toString()),
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
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ключ шифрования ksecr (256 бит)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextField(
                                    readOnly: true,
                                    controller: TextEditingController(
                                        text: kuzKey.toString()),
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
                            ),
                            const Text(
                              'Раундовые ключи',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              itemCount: roundKeys.length,
                              itemBuilder: (BuildContext context, int index) {
                                String title = 'Раунд ${index + 1}';
                                String value =
                                    kuznechik.formatBigInt(roundKeys[index]);
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      TextField(
                                        readOnly: true,
                                        controller:
                                            TextEditingController(text: value),
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
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Зашифрованный бюллетень Ben',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextField(
                                    readOnly: true,
                                    controller: TextEditingController(
                                        text: encryptedBulletin.toString()),
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
                            ),
                          ],
                        ),
                        const Text(
                          'Слепая подпись (RSA)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Случайное значение r, (p,r) = 1',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextField(
                                readOnly: true,
                                controller: TextEditingController(
                                    text: _rand.toString()),
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
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Зашифрованный ослепляющим шифрованием бюллетень Bbl',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextField(
                                readOnly: true,
                                controller: TextEditingController(
                                    text: _blind.toString()),
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
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Подписанный регистратором бюллетень DSbl',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextField(
                                readOnly: true,
                                controller: TextEditingController(
                                    text: _signed.toString()),
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
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Подписанный бюллетень со снятым шифрованием DSen',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextField(
                                readOnly: true,
                                controller: TextEditingController(
                                    text: _unblind.toString()),
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
                        ),
                      ],
                    ),
                  ))
                : const Text('Сначала проголосуйте')
          ])));
    });
  }

  Future<void> _voteCounterDialog(BuildContext context) async {
    await _buildTestCounterLoadingDialog(context);
    if (_testedCounter == 0) {
      _testCounterDialog(context);
    } else {
      await _connectCounterDialog(context);
    }
  }

  Future<void> _blindEncrypt() async {
    while (Prime.gcd(_n, _rand) != BigInt.one) {
      _rand = KuznechikRand().generateRandomBytes(16);
    }

    kuzKey = kuznechik.genKey();
    roundKeys = kuznechik.genRoundKeys(kuzKey);
    encryptedBulletin = kuznechik.encrypt(_bulletinVote, roundKeys);

    _blind = RSA.blind(encryptedBulletin, _n, _e, _rand);
  }

  Future<void> _signDialog() async {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Отправка бюллетеня',
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
    await _blindEncrypt();
    _socketReg.add(jsonEncode({'type': 'sign', 'bulletin': _blind.toString()}));
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = _authpage(context);
        break;
      case 1:
        page = _keyPage(context);
        break;
      case 2:
        page = _votePage(context);
      case 3:
        page = _cryptoPage(context);
      case 4:
        page = _resultPage(context);
      case 5:
        page = _settingsPage(context);

        break;
      default:
        throw UnimplementedError('no widget for $_selectedIndex');
    }
    return Builder(builder: (context) {
      return Scaffold(
          body: Row(
        children: [
          SafeArea(
              child: NavigationRail(
            extended: true,
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.key), label: Text('Вход')),
              NavigationRailDestination(
                  icon: Icon(Icons.lock), label: Text('Аутентификация')),
              NavigationRailDestination(
                  icon: Icon(Icons.connect_without_contact),
                  label: Text('Голосование')),
              NavigationRailDestination(
                  icon: Icon(Icons.enhanced_encryption),
                  label: Text('Шифрование бюллетеня')),
              NavigationRailDestination(
                  icon: Icon(Icons.check_box),
                  label: Text('Результаты голосования')),
              NavigationRailDestination(
                  icon: Icon(Icons.settings), label: Text('Настройки'))
            ],
            selectedIndex: _selectedIndex,
            onDestinationSelected: (value) {
              setState(() {
                _selectedIndex = value;
              });
            },
          )),
          const VerticalDivider(thickness: 2),
          Expanded(
              child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page)),
        ],
      ));
    });
  }

  Future<void> _listenCounter() async {
    await for (var message in _counterStreamController.stream) {
      if (message.runtimeType == Stop) {
        return;
      }
      var parsedMessage = jsonDecode(message);
      switch (parsedMessage['type']) {
        case 'replyOK':
          setState(() {
            _voted = true;
          });
          break;
        case 'bulletin':
          _updateBulletins(parsedMessage);
          break;
        case 'voteEnded':
          _fetchResults(parsedMessage);
          break;
        default:
          break;
      }
    }
  }

  void _updateBulletins(var parsedMessage) {
    parsedMessage.forEach((key, value) {
      if (key != 'type') {
        _voters[key.toString()] = {
          'bulletin': value['bulletin'],
          'signature': value['signature']
        };
      }
    });
    print(_voters);
    if (parsedMessage.containsKey(_code.toString())) {
      if (parsedMessage[_code.toString()]['bulletin'] ==
              encryptedBulletin.toString() &&
          !_sentKey) {
        Log().log('Получен зашифрованный бюллетень: отправляю счётчику ключ');
        _sentKey = true;
        _socketCounter.add(jsonEncode({
          'type': 'castKey',
          'id': _code.toString(),
          'key': kuzKey.toString()
        }));
      }
    }
  }

  void _fetchResults(var parsedMessage) {
    parsedMessage['voters'].forEach((key, value) {
      _voters[key]
          ?.addAll({"key": value['key'], "unencrypted": value["unencrypted"]});
    });
    _votedVoters = int.parse(parsedMessage['voted']);
    _totalVoters = int.parse(parsedMessage['totalVoters']);
    for (int i = 1; i < _bulletin.length + 1; i++) {
      _results[_bulletin[i].toString()] =
          parsedMessage['results'].containsKey(i.toString())
              ? int.parse(parsedMessage['results'][i.toString()])
              : 0;
    }
    Map<String, double> percentages = {};
    _results.forEach((key, value) {
      if (value != 0) {
        percentages[key] = (value / _votedVoters);
      }
    });
    if (percentages.values.toSet().length == 1 &&
        percentages.values.toList()[0] != 1.0) {
      _resultString = 'Объявляется второй тур!';
    } else {
      double maxPercentage = percentages.values.reduce((a, b) => a > b ? a : b);
      String winner = percentages.keys
          .where((key) => percentages[key] == maxPercentage)
          .toList()[0];
      _resultString = 'Победил кандидат "$winner"';
    }
    print(_resultString);
    _selectedIndex = 4;
  }
}
