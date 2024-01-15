class Voter {
  List<BigInt> _m = [];
  bool _authenticated = false;
  String _fio = '';
  int _regPhase = 0;
  int _authPhase = 0;
  BigInt _q = BigInt.zero;
  BigInt _p = BigInt.zero;
  BigInt _g = BigInt.zero;
  BigInt _y = BigInt.zero;
  BigInt _V = BigInt.zero;
  BigInt _c = BigInt.zero;
  BigInt n = BigInt.zero;
  BigInt e = BigInt.zero;
  BigInt d = BigInt.zero;
  BigInt _yServer = BigInt.zero;

  bool gotBulletin = false;
  int _id = -1;
  var _webSocket;

  Voter(webSocket, keys, rsakeys) {
    _webSocket = webSocket;
    _q = keys[0];
    _p = keys[1];
    _g = keys[2];
    _yServer = keys[3];
    n = rsakeys[2];
    e = rsakeys[4];
    d = rsakeys[5];
  }

  bool isAuthenticated() {
    return _authenticated;
  }

  void addVoter(BigInt m) {
    _m.add(m);
  }

  void setRegPhase(int phase) {
    _regPhase = phase;
  }

  void setAuthPhase(int phase) {
    _authPhase = phase;
  }

  int getRegPhase() {
    return _regPhase;
  }

  void setFio(String fio) {
    _fio = fio;
  }

  String getFio() {
    return _fio;
  }

  void setAuthenticated() {
    _authenticated = true;
  }

  void sendMessage(message) {
    _webSocket.sink.add(message);
  }

  void close() {
    _webSocket.sink.close();
  }

  void setKey(BigInt y, BigInt V) {
    _y = y;
    _V = V;
  }

  void setChallenge(BigInt c) {
    _c = c;
  }

  void setId(int id) {
    _id = id;
  }

  int getId() {
    return _id;
  }

  int getAuthPhase() {
    return _authPhase;
  }

  List<BigInt> getServerKey() {
    return [_p, _q, _g, _yServer];
  }

  List<BigInt> getKey() {
    return [_p, _q, _g, _y, _c, _V];
  }
}
