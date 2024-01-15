import 'dart:convert';
import 'package:counter/gost.dart';
import 'package:counter/log.dart';
import 'package:counter/provider.dart';
import 'package:counter/rsa.dart';
import 'package:counter/schnorr.dart';

class Client {
  var _websocket;
  bool isRegistrar = false;
  BigInt _q = BigInt.zero;
  BigInt _p = BigInt.zero;
  BigInt _g = BigInt.zero;
  BigInt _y = BigInt.zero;
  BigInt _v = BigInt.zero;
  BigInt _c = BigInt.zero;
  BigInt _r = BigInt.zero;
  BigInt _yRegistrar = BigInt.zero;
  late VoterProvider _voterProvider;
  Map<String, List<BigInt>> bulletin = {};
  int minutes = 0;
  Client(websocket, VoterProvider voterProvider) {
    _voterProvider = voterProvider;
    _websocket = websocket;
    _yRegistrar = voterProvider.getPubKey();
    var keys = voterProvider.keys;
    _q = keys[0];
    _p = keys[1];
    _g = keys[2];
  }

  String _login1(Map<String, dynamic> message) {
    print('Получение ключей от пользователя');
    if (!message.containsKey('y') || !message.containsKey('V')) {
      _authPhase = 0;
      return 'PubKey not accepted';
    }
    _y = BigInt.parse(message['y']!);
    if (_y != _yRegistrar) {
      _authPhase = 0;
      return 'Not a registrar';
    }
    _v = BigInt.parse(message['V']);
    _authPhase = 1;
    BigInt c = Schnorr.genChallenge();
    print('Отправляю c = $c');
    return json.encode({'c': c.toString()});
  }

  String _login2(Map<String, dynamic> message) {
    if (!(message.containsKey('r'))) {
      _authPhase = 0;
      return 'No proof provided';
    }
    _r = BigInt.parse(message['r']);
    bool ver = Schnorr.verifyLogin(_p, _q, _g, _r, _y, _c, _v);
    if (ver) {
      print('Регистратор успешно аутентифицировался');
      isRegistrar = true;
      _authPhase = 0;

      return '1';
    } else {
      _authPhase = 0;
      print('Аутентификация провалилась...');
      return '0';
    }
  }

  int _authPhase = 0;
  String handle(message) {
    late var jsonMessage;
    try {
      jsonMessage = json.decode(message);
    } catch (_) {
      return jsonEncode({'type': 'replyFail'});
    }
    switch (jsonMessage['type']) {
      case 'regAuth':
        switch (_authPhase) {
          case 0:
            return _login1(jsonMessage);
          case 1:
            return _login2(jsonMessage);
          default:
            break;
        }
        break;
      case 'voteStarted':
        if (!isRegistrar) {
          return 'forbidden';
        } else {
          _voterProvider.n = BigInt.parse(jsonMessage['n']);
          _voterProvider.e = BigInt.parse(jsonMessage['e']);
          _voterProvider.minutes = jsonMessage['time'];
          _voterProvider.voters = jsonMessage['voters'];
          _voterProvider.startVote();
          _voterProvider.update();
          return jsonEncode({'type': 'replyOK'});
        }
      case 'castVote':
        Log().log('Избиратель отправил бюллетень');
        if (!_voterProvider.voteStarted) {
          Log().log('Голосование пока не началось');
          return jsonEncode({'type': 'voteNotStarted'});
        }
        if (!jsonMessage.containsKey('id') ||
            !jsonMessage.containsKey('bulletin') ||
            !jsonMessage.containsKey('signature')) {
          Log().log('Избиратель отправил неправильно сформированный запрос');
          return jsonEncode({'type': 'replyFail'});
        }
        BigInt bulletin = BigInt.parse(jsonMessage['bulletin']);
        BigInt signature = BigInt.parse(jsonMessage['signature']);
        if (!RSA.verify(
            bulletin, signature, _voterProvider.n, _voterProvider.e)) {
          Log().log('Подпись неверна');
          return jsonEncode({'type': 'voterNotFound'});
        } else {
          Log().log('Подпись верна');
          String id = jsonMessage['id'];
          BigInt bulletin = BigInt.parse(jsonMessage['bulletin']);
          BigInt signature = BigInt.parse(jsonMessage['signature']);
          _voterProvider.addVoter(id, bulletin, signature);
          _voterProvider.update();
          return jsonEncode({'type': 'replyOK'});
        }
      case 'castKey':
        if (!_voterProvider.bulletin.containsKey(jsonMessage['id'])) {
          Log().log('Избиратель отправил ключ без метки');
          return jsonEncode({'reply': 'voterNotFound'});
        } else {
          Log().log('Получен ключ');
          BigInt key = BigInt.parse(jsonMessage['key']);
          String id = jsonMessage['id'];
          BigInt bulletin = _voterProvider.bulletin[id]!['bulletin']!;
          BigInt unencrypted = decrypt(bulletin, key);
          BigInt result = unencrypted;
          _voterProvider.bulletin[id]?['key'] = key;
          _voterProvider.bulletin[id]?['result'] = result;
          _voterProvider.bulletin[id]?['unencrypted'] = unencrypted;
          _voterProvider.voted++;
          _voterProvider.update();
          return jsonEncode({'type': 'replyOK'});
        }
      default:
        return 'unknown command';
    }
    return 'unknown command';
  }

  void sendMessage(message) {
    _websocket.sink.add(message);
  }

  BigInt decrypt(BigInt bulletin, BigInt key) {
    List<BigInt> roundKeys = Kuznechik().genRoundKeys(key);
    BigInt unencrypted = Kuznechik().decrypt(bulletin, roundKeys);
    return unencrypted;
  }
}
