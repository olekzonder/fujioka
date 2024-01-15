import 'dart:convert';

class Vote {
  Map<BigInt, (BigInt, BigInt)> _votersM = {};

  void addVoter(Map<BigInt, (BigInt, BigInt)> m) {
    _votersM.addAll(m);
  }

  void updateKeys(Map<BigInt, (BigInt, BigInt)> m) {
    _votersM.addAll(m);
  }

  bool findVoter(m) {
    return _votersM.containsKey(m);
  }

  Map<String, String> getBulletins() {
    Map<String, String> bulletins = {};
    _votersM.forEach((key, value) {
      String m = key.toString();
      String mb = value.$1.toString();
      bulletins.addAll({m: mb});
    });
    return bulletins;
  }

  List<int> getResults() {
    return [1, 2, 3, 4];
  }
}
