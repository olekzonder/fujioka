import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:registrar/crypto/schnorr.dart';
import 'package:registrar/log.dart';
import 'package:registrar/providers.dart';

class IncorrectServerException implements Exception {
  String cause;
  IncorrectServerException(this.cause);
}

class Stop {}

class Counter {
  late VoterProvider _provider;
  Counter(VoterProvider provider) {
    _provider = provider;
  }
  late String _ipCounter;

  var _socketCounter;
  String _counterErr = '';
  String get counterErr => _counterErr;
  bool _connectedCounter = false;
  bool get connectedCounter => _connectedCounter;

  bool authenticated = false;
  bool _ver = false;

  bool voteStarted = false;
  int loginError = 0;
  int _authPhase = -1;
  BigInt _q = BigInt.zero;
  BigInt _p = BigInt.zero;
  BigInt _g = BigInt.zero;
  BigInt _x = BigInt.zero;
  BigInt _y = BigInt.zero;
  BigInt _v = BigInt.zero;
  BigInt _V = BigInt.zero;
  BigInt _c = BigInt.zero;
  BigInt _r = BigInt.zero;
  bool _connected = false;
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();

  final StreamController<bool> sendStreamer = StreamController<bool>();
  void setIP(ip) {
    _ipCounter = ip;
  }

  Future<void> testCounter() async {
    try {
      _socketCounter = await WebSocket.connect('ws://$_ipCounter');
      _counterErr = '';
      Log().log('Успешно подключился к серверу');
      await for (var message in _socketCounter) {
        if (message == 'counter') {
          break;
        } else {
          throw IncorrectServerException('Сервер не является счётчиком');
        }
      }
      _connectedCounter = true;
      _socketCounter.close();
    } on SocketException catch (e) {
      _connectedCounter = false;
      _counterErr = e.message;
    } on WebSocketException catch (e) {
      _connectedCounter = false;
      _counterErr = e.message;
    } on ArgumentError catch (e) {
      _connectedCounter = false;
      _counterErr = e.message;
    } on IncorrectServerException catch (e) {
      _connectedCounter = false;
      _counterErr = e.cause;
    }
  }

  Future<void> connectCounter() async {
    if (_connected) return;
    try {
      _socketCounter = await WebSocket.connect('ws://$_ipCounter');
      _connected = true;
      _socketCounter.listen((data) {
        Log().log('Получено сообщение от счётчика: $data');
        if (data != 'counter') {
          _streamController.add(data);
        }
      }, onDone: () {
        _connected = false;
        Log().log('Соединение с счётчиком закрыто');
        _provider.stopVote();
        _streamController.sink.add(Stop());
      }, onError: (error) {
        _connected = false;
        Log().log('Error: $error');
        _provider.stopVote();
        _streamController.sink.add(Stop());
        _streamController.close();
      });
      Log().log('Подключен к регистратору');
    } catch (e) {
      Log().log('Не удалось подключиться к регистратору: $e');
    }
  }

  Future<void> startLogin(List<BigInt> keys) async {
    _authPhase = 0;
    authenticated = false;
    loginError = 0;
    _q = keys[0];
    _p = keys[1];
    _g = keys[2];
    _y = keys[4];
    _v = Schnorr.genV(_p, _q);
    _V = Schnorr.genVCap(_q, _p, _g, _v);
    _socketCounter.add(jsonEncode(
        {'type': 'regAuth', 'y': keys[4].toString(), 'V': _V.toString()}));
    _listen();
  }

  Future<void> _login(String message) async {
    switch (_authPhase) {
      case 0:
        if (message == 'Not a registrar' || message == 'PubKey not accepted') {
          loginError = 1;
          _authPhase = -1;
          sendStreamer.sink.add(false);
          _streamController.sink.add(Stop);
          Log().log('Аутентификация счётчика провалилась');
          break;
        }
        var msg = jsonDecode(message);
        _c = BigInt.parse(msg['c'].toString());
        _r = Schnorr.computeChallenge(_v, _x, _c, _q);
        _socketCounter.add(jsonEncode({'type': 'regAuth', 'r': _r.toString()}));
        _authPhase++;
        Log().log('Аутентификация счётчика успешна');
        break;
      case 1:
        if (message == '1') {
          sendStreamer.sink.add(true);
          authenticated = true;
          _ver = true;
          _authPhase = -1;
        } else {
          sendStreamer.sink.add(false);
          authenticated = false;
          _ver = false;
          _authPhase = -1;
        }
        break;
      default:
        break;
    }
  }

  void _handleMessage(message) {
    late var jsonMessage;
    try {
      jsonMessage = jsonDecode(message);
    } catch (_) {
      return;
    }
    if (jsonMessage['type'] == 'voteEnded') {
      Log().log('Заканчиваю голосование');
      _provider.stopVote();
    }
  }

  Future<void> _listen() async {
    await for (var message in _streamController.stream) {
      if (message.runtimeType == Stop) {
        return;
      }
      if (_authPhase > -1) {
        _login(message);
      } else {
        _handleMessage(message);
      }
    }
  }

  bool getVer() {
    return _ver;
  }

  void startVote(minutes) {
    Log().log('Начинаю голосование');
    voteStarted = true;
    _socketCounter.add(jsonEncode({
      'type': 'voteStarted',
      'n': _provider.rsaKeys[2].toString(),
      'e': _provider.rsaKeys[4].toString(),
      'voters': _provider.voters.length,
      'time': minutes
    }));
  }
}
