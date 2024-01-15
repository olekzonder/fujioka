import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:registrar/database.dart';
import 'package:registrar/handler.dart';
import 'package:registrar/log.dart';
import 'package:registrar/voter.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'crypto/prime.dart';
import 'crypto/rsa.dart';

class Server {
  var connections = <dynamic>{};
  DatabaseHelper dbhelper = DatabaseHelper();
  int _connectedVoters = 0;
  bool _canRegister = true;
  bool get canRegister => _canRegister;
  bool _voteStarted = false;
  List<BigInt> keys = [];
  List<BigInt> _rsaKeys = []; //p,q,n,phi,e,d
  Map<int, List<String>> _voters = {};
  List<int> voted = [];
  Map<String, String> _bulletin = {};
  final StreamController<Map<int, dynamic>> _voterOnlineStream =
      StreamController<Map<int, dynamic>>();
  Stream<Map<int, dynamic>> get voterOnlineStream => _voterOnlineStream.stream;

  Future<void> startVote() async {
    Log().log('Голосование начато!');
    _canRegister = false;
    _voteStarted = true;
    voted = [];
    sendBulletins();
  }

  void blockRegister() {
    _canRegister = true;
  }

  void unlockRegister() {
    _canRegister = false;
  }

  Future<void> resetDatabase() async {
    for (var connection in connections) {
      connection.close();
    }
    connections.clear();
    await dbhelper.resetTables();
    _voters.clear();
    keys = await dbhelper.getKeys();
    await genRSA();
    _voterOnlineStream.add({0: _voters});
    _voterOnlineStream.add({1: keys});
    _voterOnlineStream.add({4: _rsaKeys});
  }

  Future<void> startDB() async {
    await dbhelper.open();
    keys = await dbhelper.getKeys();
    _voterOnlineStream.add({1: keys});
    dbhelper.databaseStream.listen((voters) {
      _voterOnlineStream.add({0: voters});
      _voters = voters;
    });
    await genRSA();
    _voterOnlineStream.add({4: _rsaKeys});
  }

  Map<int, List<String>> getVoters() {
    return _voters;
  }

  List<BigInt> getKeys() {
    return keys;
  }

  void setBulletin(Map<int, String> bulletin) {
    _bulletin = {};
    for (int i = 0; i < bulletin.length; i++) {
      _bulletin[i.toString()] = bulletin.values.elementAt(i);
    }
    _bulletin['type'] = 'bulletin';
  }

  void sendBulletins() {
    for (var connection in connections) {
      if (connection.isAuthenticated()) {
        Map<String, String> sentBulletin = _bulletin;
        connection.sendMessage(jsonEncode(sentBulletin));
      }
    }
  }

  void sendBulletin(connection) {
    connection.gotBulletin = true;
    Map<String, String> sentBulletin = _bulletin;
    connection.sendMessage(jsonEncode(sentBulletin));
  }

  void stopVote() {
    _canRegister = true;
    _voteStarted = false;
  }

  Future<void> genRSA() async {
    _rsaKeys = await Isolate.run(RSA.generate);
    Log().log('--Генерация RSA--');
    Log().log('Простое число p: ${_rsaKeys[0]}');
    Log().log('Простое число q: ${_rsaKeys[1]}');
    Log().log('n = p*q: ${_rsaKeys[2]}');
    Log().log('φ(n) = (p-1) * (q-1): ${_rsaKeys[3]}');
    Log().log('Открытая экспонента e: ${_rsaKeys[4]}');
    Log().log('Секретная экспонента d: ${_rsaKeys[5]}');
  }

  void serve() async {
    await startDB();
    var handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(webSocketHandler((webSocket) {
      webSocket.sink.add('registrar');
      Voter voter =
          Voter(webSocket, [keys[0], keys[1], keys[2], keys[4]], _rsaKeys);
      connections.add(voter);
      Handler response = Handler(voter, dbhelper);
      webSocket.stream.listen((message) async {
        Log().log('Получено сообщение от избирателя: $message');
        var output = await response.handle(message, _canRegister, voted);
        webSocket.sink.add(output);
        if (voter.isAuthenticated()) {
          _connectedVoters++;
          _voterOnlineStream.add({3: _connectedVoters});
          if (_voteStarted && !voter.gotBulletin) {
            sendBulletin(voter);
          }
        }
      }, onDone: () {
        Log().log('Клиент отключился');
        if (voter.isAuthenticated()) {
          _connectedVoters--;
          _voterOnlineStream.add({3: _connectedVoters});
        }
        connections.remove(voter);
      });
    }));

    shelf_io.serve(handler, 'localhost', 11101).then((server) {
      Log().log('Регистратор запущен по адресу localhost:${server.port}');
    });
  }

  Future<void> deleteUser(int id) async {
    connections.removeWhere((connection) {
      if (connection.getId() == id) {
        connection.close();
        return true;
      }
      return false;
    });
    await dbhelper.removeUser(id);
  }
}

void main() async {
  final server = Server();
  server.serve();
}
