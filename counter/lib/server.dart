import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:counter/log.dart';
import 'package:counter/provider.dart';
import 'package:counter/schnorr.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'client.dart';

class Server {
  var connections = <dynamic>{};
  bool _registrarAuthed = false;
  List<BigInt> keys = [];
  BigInt pubKey = BigInt.zero;
  late VoterProvider _voterProvider;

  Server(VoterProvider voterProvider) {
    _voterProvider = voterProvider;
  }

  final StreamController<Map<int, dynamic>> _voterOnlineStream =
      StreamController<Map<int, dynamic>>();
  Stream<Map<int, dynamic>> get voterOnlineStream => _voterOnlineStream.stream;

  Future<void> startServer() async {
    await resetKeys();
    serve();
  }

  Future<void> resetKeys() async {
    keys = await Isolate.run(Schnorr.generate);
    _voterProvider.setKeys(keys);
  }

  void serve() {
    var handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(webSocketHandler((webSocket) {
      Log().log('Клиент подключился');
      webSocket.sink.add('counter');
      Client client = Client(webSocket, _voterProvider);
      connections.add(client);
      String response = '';
      webSocket.stream.listen((message) {
        Log().log('Получено сообщение: $message');
        response = client.handle(message);
        webSocket.sink.add(response);
        if (client.isRegistrar == true) {
          _registrarAuthed = true;
        }
      }, onDone: () {
        if (client.isRegistrar) {
          _registrarAuthed = false;
          Log().log('Регистратор отключился...');
        } else {
          Log().log('Клиент отключился');
        }
        connections.remove(client);
      });
    }));

    shelf_io.serve(handler, 'localhost', 11102).then((server) {
      Log().log('Счётчик запущен: localhost:${server.port}');
    });
  }

  void sendIntermediateBulletins() {
    Map<String, dynamic> bulletin = {};
    _voterProvider.bulletin.forEach((key, value) {
      if (value['bulletin'] != null) {
        bulletin[key] = {
          'bulletin': value['bulletin'].toString(),
          'signature': value['signature'].toString(),
        };
      }
    });
    bulletin['type'] = 'bulletin';
    for (var connection in connections) {
      if (connection.isRegistrar) continue;
      connection.sendMessage(jsonEncode(bulletin));
    }
  }

  void sendResults() {
    Map<String, dynamic> results = {};
    results['results'] = _voterProvider.results;

    results['voters'] = {};
    _voterProvider.bulletin.forEach((key, value) {
      if (value['result'] != null) {
        results['voters'][key] = {
          'key': value['key'].toString(),
          'unencrypted': value['unencrypted'].toString()
        };
      }
    });
    results['type'] = 'voteEnded';
    results['totalVoters'] = _voterProvider.voters.toString();
    results['voted'] = _voterProvider.voted.toString();
    Log().log("Отправляю избирателям сообщение $results");
    for (var connection in connections) {
      if (connection.isRegistrar) {
        connection.sendMessage(jsonEncode({'type': 'voteEnded'}));
      } else {
        connection.sendMessage(jsonEncode(results));
      }
    }
  }

  void stopVote() {
    Log().log('Голосование завершено');
    sendResults();
  }
}
