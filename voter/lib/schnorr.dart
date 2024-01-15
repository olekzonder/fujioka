import 'prime.dart';
import 'random.dart';

class Schnorr extends Prime {
  static int plen = 1024; // длина p
  static int qlen = 160; // длина q
  static int tlen = 64;
  static BigInt _genQ() {
    BigInt q = BigInt.from(0);
    while (true) {
      q = KuznechikRand().generateRandomBytes(qlen ~/ 8);
      if (Prime.testMillerRabin(q, 19) && Prime.testLucas(q)) {
        break;
      }
    }
    return q;
  }

  static BigInt _genP(q) {
    BigInt p = BigInt.from(0);
    BigInt k = BigInt.from(0);
    int klen = plen - qlen;
    while (true) {
      k = KuznechikRand().generateRandomBytes(klen ~/ 8);
      p = k * q + BigInt.one;
      if (Prime.testMillerRabin(p, 3) && Prime.testLucas(p)) {
        break;
      }
    }
    return p;
  }

  static BigInt _genG(p, q) {
    BigInt g = BigInt.from(0);
    BigInt e = (p - BigInt.one) ~/ q;
    while (true) {
      BigInt h = KuznechikRand().generateRandomBytes(qlen ~/ 8);
      g = h.modPow(e, p);
      if (g != BigInt.one && g < p) {
        break;
      }
    }
    return g;
  }

  static List<BigInt> genKeys(p, q, g) {
    BigInt a = KuznechikRand().generateRandomBytes(qlen ~/ 8).remainder(q);

    BigInt A = Prime.moduloInverse(g, a, p);

    return [a, A];
  }

  static List<BigInt> generate() {
    BigInt q = _genQ();
    BigInt p = _genP(q);
    BigInt g = _genG(p, q);
    List<BigInt> keys = genKeys(p, q, g);
    return [q, p, g, keys[0], keys[1]];
  }

  static BigInt genV(p, q) {
    return KuznechikRand()
            .generateRandomBytes((qlen + 64) ~/ 8)
            .remainder(q - BigInt.one) +
        BigInt.one;
  }

  static BigInt genVCap(BigInt q, BigInt p, BigInt g, BigInt v) {
    return g.modPow(v, p);
  }

  static BigInt genChallenge() {
    return KuznechikRand().generateRandomBytes(tlen ~/ 8);
  }

  static BigInt computeChallenge(BigInt v, BigInt a, BigInt c, BigInt q) {
    var res = (v + (a * c)) % q;

    return res; //r
  }

  static bool verifyLogin(
      BigInt p, BigInt q, BigInt g, BigInt r, BigInt A, BigInt c, BigInt v) {
    if (A <= BigInt.one || A >= p - BigInt.one) {
      print('Не прошла аутентификация: открытый ключ больше p');
      return false;
    }

    if ((g.modPow(r, p) * (A.modPow(c, p))).remainder(p) != v) {
      print("V != g^r * A^c mod p");
      return false;
    }

    return true;
  }
}

void main() {
  List<BigInt> keys = Schnorr.generate();
  var q = keys[0];
  var p = keys[1];
  var g = keys[2];
  var x = keys[3];
  var y = keys[4];
  print(x);
  print(y);
  var v = Schnorr.genV(p, q);
  var V = Schnorr.genVCap(q, p, g, v);
  var c = Schnorr.genChallenge();
  var r = Schnorr.computeChallenge(v, x, c, q);
  print(Schnorr.verifyLogin(p, q, g, r, y, c, V));
}
