import 'dart:async';

import 'package:flutter/material.dart';
import 'package:counter/server.dart';

class VoterProvider extends ChangeNotifier {
  late Server _server;

  List<BigInt> _keys = [];

  List<BigInt> get keys => _keys;

  final Map<String, Map<String, BigInt>> _bulletin = {};
  Map<String, Map<String, BigInt>> get bulletin => _bulletin;

  Map<String, String> _results = {};
  Map<String, String> get results => _results;
  BigInt n = BigInt.zero;
  BigInt e = BigInt.zero;
  int authorizedVoters = 0;
  int minutes = 0;
  int voters = 0;
  int voted = 0;
  bool _serverRunning = false;
  bool voteStarted = false;
  bool voteEnded = false;
  bool secondTour = false;
  Timer? _timer;
  int remainingTime = 0;

  Future<void> startServer(VoterProvider of) async {
    if (_serverRunning) return;
    _serverRunning = true;
    _server = Server(of);
    await _server.startServer();
    notifyListeners();
  }

  void setKeys(List<BigInt> keys) {
    _keys = keys;
    notifyListeners();
  }

  void addVoter(id, bulletin, signature) {
    _bulletin[id] = {'bulletin': bulletin, 'signature': signature};
    _server.sendIntermediateBulletins();
    notifyListeners();
  }

  void setPubkey(BigInt key) {
    _server.pubKey = key;
    notifyListeners();
  }

  BigInt getPubKey() {
    return _server.pubKey;
  }

  void resetKeys() {
    _keys = [];
    notifyListeners();
    _server.resetKeys();
  }

  void update() {
    notifyListeners();
  }

  void _startTimer() {
    remainingTime = minutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingTime--;
      if (remainingTime == 0 || voted == voters) {
        _timer?.cancel();
        stopVote();
      }
      notifyListeners();
    });
  }

  void startVote() {
    voteStarted = true;
    voteEnded = false;
    _bulletin.clear();
    _results.clear();
    secondTour = false;
    voted = 0;
    _startTimer();
    notifyListeners();
  }

  Map<String, String> calculateResults() {
    List<int> choices = [];
    bulletin.forEach((key, value) {
      if (value.containsKey('result')) {
        choices.add(value['result']!.toInt());
      }
    });
    Map<int, int> countMap = {};

    for (var element in choices) {
      countMap[element] = (countMap[element] ?? 0) + 1;
    }

    List<double> percentages = [];
    countMap.forEach((key, value) {
      if (value != 0) {
        percentages.add(value / voters);
      }
    });
    if (percentages.toSet().length == 1 && percentages[0] != 1.0) {
      secondTour = true;
    }
    Map<String, String> convertedMap = {};

    for (var element in choices) {
      convertedMap[element.toString()] = (countMap[element] ?? 0).toString();
    }

    return convertedMap;
  }

  void stopVote() {
    _results = calculateResults();
    _server.stopVote();
    voteEnded = true;
  }
}
