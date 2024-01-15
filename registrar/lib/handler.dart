import 'dart:convert';

import 'package:registrar/crypto/rsa.dart';
import 'package:registrar/database.dart';
import 'package:registrar/crypto/schnorr.dart';
import 'package:registrar/providers.dart';
import 'package:registrar/voter.dart';

class Handler {
  late Voter _voter;
  late DatabaseHelper _dbhelper;

  Handler(voter, dbhelper) {
    _voter = voter;
    _dbhelper = dbhelper;
  }

  String _reg0() {
    print("Пользователь начинает регистрацию");
    _voter.setRegPhase(1);
    var keys = _voter.getServerKey();
    return jsonEncode({
      'p': keys[0].toString(),
      'q': keys[1].toString(),
      'g': keys[2].toString(),
      'y': keys[3].toString()
    });
  }

  String _reg1(Map<String, dynamic> message) {
    print('Получение ключей от пользователя');
    if (!message.containsKey('y') && message.containsKey('V')) {
      _voter.setRegPhase(0);
      return 'PubKey not accepted';
    }
    if (!message.containsKey('fio')) {
      _voter.setRegPhase(0);
      return 'No string';
    }
    BigInt y = BigInt.parse(message['y']!);
    BigInt V = BigInt.parse(message['V']!);
    print('y=$y');
    print('r=$V');
    String fio = message['fio'];
    print('ФИО: $fio');
    _voter.setRegPhase(2);
    _voter.setKey(y, V);
    _voter.setFio(fio);
    BigInt c = Schnorr.genChallenge();
    _voter.setChallenge(c);
    print('Отправляю c = $c');
    return c.toString();
  }

  Future<String> _reg2(Map<String, dynamic> message) async {
    if (!(message.containsKey('r'))) {
      _voter.setRegPhase(0);
      return 'No proof provided';
    }
    BigInt r = BigInt.parse(message['r']!);
    List<BigInt> key = _voter.getKey();
    bool ver =
        Schnorr.verifyLogin(key[0], key[1], key[2], r, key[3], key[4], key[5]);
    if (ver) {
      _voter.setAuthenticated();
      _voter.setRegPhase(0);
      print('${_voter.getFio()} успешно зарегистрировался');
      _dbhelper.addUser(_voter.getFio(), key[3].toString());
      int id = await _dbhelper.checkUser(key[3].toString());
      _voter.setId(id);
      return jsonEncode({'e': _voter.e.toString(), 'n': _voter.n.toString()});
    } else {
      _voter.setRegPhase(0);
      print('Регистрация провалилась...');
      return '0';
    }
  }

  String _login0() {
    print("Пользователь начинает аутентификацию");
    _voter.setAuthPhase(1);
    var keys = _voter.getServerKey();
    return jsonEncode({
      'p': keys[0].toString(),
      'q': keys[1].toString(),
      'g': keys[2].toString(),
      'y': keys[3].toString()
    });
  }

  Future<String> _login1(Map<String, dynamic> message) async {
    print('Получение ключей от пользователя');
    if (!message.containsKey('y') && message.containsKey('V')) {
      _voter.setAuthPhase(0);
      return 'PubKey not accepted';
    }
    var id = await _dbhelper.checkUser(message['y']);
    if (id == -1) {
      return 'User was not found in the database';
    }
    BigInt y = BigInt.parse(message['y']!);
    BigInt V = BigInt.parse(message['V']);
    String fio = await _dbhelper.getFio(id);
    _voter.setAuthPhase(2);
    _voter.setKey(y, V);
    _voter.setFio(fio);
    _voter.setId(id);
    BigInt c = Schnorr.genChallenge();
    _voter.setChallenge(c);
    print('Отправляю c = $c');
    return jsonEncode({'c': c.toString(), 'fio': fio});
  }

  Future<String> _login2(Map<String, dynamic> message) async {
    if (!(message.containsKey('r'))) {
      _voter.setAuthPhase(0);
      return 'No proof provided';
    }
    BigInt r = BigInt.parse(message['r']!);
    List<BigInt> key = _voter.getKey();
    bool ver =
        Schnorr.verifyLogin(key[0], key[1], key[2], r, key[3], key[4], key[5]);
    if (ver) {
      _voter.setAuthenticated();
      _voter.setAuthPhase(0);
      print('${_voter.getFio()} успешно аутентифицировался');
      return jsonEncode({'e': _voter.e.toString(), 'n': _voter.n.toString()});
    } else {
      _voter.setAuthPhase(0);
      print('Аутентификация провалилась...');
      return '0';
    }
  }

  Future<String> handle(message, canRegister, List<int> voted) async {
    switch (message) {
      case 'register':
        if (!canRegister) {
          return 'Forbidden';
        }
        _voter.setRegPhase(0);
        _voter.setAuthPhase(0);
        return _reg0();
      case 'login':
        _voter.setRegPhase(0);
        _voter.setAuthPhase(0);
        return _login0();
      default:
        if (_voter.getRegPhase() > 0) {
          switch (_voter.getRegPhase()) {
            case 1:
              return _reg1(jsonDecode(message));
            case 2:
              return _reg2(jsonDecode(message));
            default:
              break;
          }
        } else if (_voter.getAuthPhase() > 0) {
          switch (_voter.getAuthPhase()) {
            case 1:
              return await _login1(jsonDecode(message));
            case 2:
              return _login2(jsonDecode(message));
            default:
              break;
          }
        }
    }
    late var jsonMessage;
    try {
      jsonMessage = jsonDecode(message);
    } catch (_) {
      return 'unknown command';
    }
    switch (jsonMessage['type']) {
      case 'sign':
        if (!_voter.isAuthenticated()) {
          return 'forbidden';
        }
        if (voted.contains(_voter.getId())) {
          return jsonEncode({'type': 'alreadyVoted'});
        }
        if (!jsonMessage.containsKey('bulletin')) {
          return 'no bulletin provided';
        }
        var signed =
            RSA.sign(BigInt.parse(jsonMessage['bulletin']), _voter.n, _voter.d);
        voted.add(_voter.getId());
        return jsonEncode({'type': 'sign', 'bulletin': signed.toString()});
    }
    return 'no command supplied';
  }
}
