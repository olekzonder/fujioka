import 'dart:async';

import 'package:flutter/material.dart';
import 'package:registrar/server.dart';

class VoterProvider extends ChangeNotifier {
  late Server _server;
  Map<int, List<String>> _voters = {};
  Map<int, List<String>> get voters => _voters;
  List<BigInt> _keys = [];
  List<BigInt> get keys => _keys;

  List<BigInt> _authKeys = [];
  List<BigInt> get authKeys => _authKeys;

  List<BigInt> _rsaKeys = [];
  List<BigInt> get rsaKeys => _rsaKeys;
  Map<int, String> _bulletin = {};
  Map<int, String> get bulletin => _bulletin;

  int authorizedVoters = 0;
  late StreamSubscription<Map<int, dynamic>> _voterOnlineStream;
  bool _serverRunning = false;
  bool voteStarted = false;

  Future<void> startServer() async {
    if (_serverRunning) return;
    _serverRunning = true;
    _server = Server();
    _server.serve();
    _server.getKeys();
    _voterOnlineStream =
        _server.voterOnlineStream.listen((Map<int, dynamic> value) {
      value.forEach((key, value) {
        switch (key) {
          case 0:
            _voters = value;
            break;
          case 1:
            _keys = value;
            break;
          case 3:
            authorizedVoters = value;
            break;
          case 4:
            _rsaKeys = value;
        }
      });
      notifyListeners();
    });
  }

  Future<void> resetDatabase() async {
    _server.stopVote();
    voteStarted = false;
    await Future.wait([
      _server.resetDatabase(),
    ]);
    notifyListeners();
  }

  void deleteUser(int id) {
    _server.deleteUser(id);
    notifyListeners();
  }

  void setBulletin(Map<int, String> bulletin) {
    _bulletin = bulletin;
    _server.setBulletin(_bulletin);
  }

  Future<void> startVote() async {
    await _server.startVote();
    voteStarted = true;
    notifyListeners();
  }

  void setCounterAuth(BigInt q, BigInt p, BigInt g, BigInt x, BigInt y) {
    _authKeys = [q, p, g, x, y];
  }

  void stopVote() async {
    _server.stopVote();
    voteStarted = false;
    _bulletin.clear();
    notifyListeners();
  }
}
