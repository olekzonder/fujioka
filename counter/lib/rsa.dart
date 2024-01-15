import 'prime.dart';
import 'random.dart';

class RSA {
  static List<BigInt> generate() {
    //p,q,n,phi,e,d
    BigInt p = genRandom();
    BigInt q = genRandom();
    BigInt n = p * q;
    BigInt phi = (p - BigInt.one) * (q - BigInt.one);
    BigInt e = _generateE(phi);
    BigInt d = _generateD(e, phi);
    return [p, q, n, phi, e, d];
  }

  static BigInt _generateE(BigInt phi) {
    while (true) {
      var potentialE = KuznechikRand().generateRandomBytes(32);
      if (Prime.gcd(potentialE, phi) == BigInt.one) {
        return potentialE;
      }
    }
  }

  static BigInt _generateD(BigInt e, BigInt phi) {
    return Prime.moduloInverse(e, BigInt.one, phi);
  }

  static BigInt blind(BigInt message, BigInt n, BigInt e, BigInt r) {
    //message,n,e,r
    return (message * r.modPow(e, n)) % n;
  }

  static BigInt unblind(BigInt blindedMessage, BigInt n, BigInt r) {
    //message,n,r
    var rInverse = r.modInverse(n);
    return (blindedMessage * rInverse) % n;
  }

  static BigInt sign(BigInt message, BigInt n, BigInt d) {
    //mesage,n,d
    return message.modPow(d, n);
  }

  static bool verify(BigInt message, BigInt signature, BigInt n, BigInt e) {
    //message,signature,n,e
    var decryptedSignature = signature.modPow(e, n);
    return decryptedSignature == message;
  }

  static BigInt genRandom() {
    BigInt q = BigInt.from(0);
    while (true) {
      q = KuznechikRand().generateRandomBytes(64);
      if (Prime.testMillerRabin(q, 32) && Prime.testLucas(q)) {
        break;
      }
    }
    return q;
  }
}

void main() {
  // Слепая подпись
  var keys = RSA.generate();
  BigInt p = keys[0];
  BigInt q = keys[1];
  BigInt n = keys[2];
  BigInt phi = keys[3];
  BigInt e = keys[4];
  BigInt d = keys[5];
  var message = BigInt.parse('150849345859996067717791744056220238460');
  var r = KuznechikRand().generateRandomBytes(32);
  while (Prime.gcd(p, r) != BigInt.one) {
    r = KuznechikRand().generateRandomBytes(32);
  }
  var blindedMessage = RSA.blind(message, n, e, r);
  var signature = RSA.sign(blindedMessage, n, d);
  var unblindedSignature = RSA.unblind(signature, n, r);

  // Проверка подписи
  var isVerified = RSA.verify(message, unblindedSignature, n, e);

  print('Сообщение: $message');
  print('Зашифрованное сообщение: $blindedMessage');
  print('Слепая подпись: $signature');
  print('Подписанное сообщение: $unblindedSignature');
  print('Сообщение == подписанное сообщение: $isVerified');
}
