import 'dart:typed_data';
import 'dart:math';

import 'package:convert/convert.dart';

import 'gost.dart';

class KuznechikRand {
  static final KuznechikRand _instance = KuznechikRand._internal();
  late BigInt _nonce;

  factory KuznechikRand() {
    return _instance;
  }
  KuznechikRand._internal() {
    _nonce = _generateNonce();
  }

  Uint8List _bigIntToBytes(BigInt number) {
    String string = number.toRadixString(16);
    if (string.length < 32) {
      string = '0' * (32 - string.length) + string;
    }
    if (string.length == 63) {
      string = '0' + string;
    }
    var byteCount = (string.length + 1) ~/ 2;
    var uint8List = Uint8List(byteCount);
    byteCount = (string.length + 1) ~/ 2;
    uint8List = Uint8List(byteCount);
    for (var i = 0; i < byteCount; i++) {
      final startIndex = i * 2;
      final endIndex = startIndex + 2;
      final byteString = string.substring(startIndex, endIndex);
      final byte = int.parse(byteString, radix: 16);
      uint8List[i] = byte;
    }

    return uint8List;
  }

  // Реализация функций шифрования и расшифрования
  Kuznechik kuz = Kuznechik();
  BigInt _bytesToBigInt(Uint8List bytes, int length) {
    String hexString = hex.encode(bytes);
    return BigInt.parse(hexString, radix: 16).toUnsigned(length);
  }

  BigInt _generateNonce() {
    BigInt randomBigInt = BigInt.zero;
    final random = Random();
    while (randomBigInt.bitLength < 256) {
      final randomBytes = Uint8List.fromList(
          List<int>.generate(256, (index) => random.nextInt(256)));
      randomBigInt = _bytesToBigInt(randomBytes, 256);
    }

    return randomBigInt;
  }

  BigInt generateRandomBytes(int length) {
    // print(length);
    List<BigInt> keys = kuz.genRoundKeys(_nonce);
    List<int> randomBytes = [];
    int remainingLength = length;
    while (remainingLength > 0) {
      List<BigInt> keys = kuz.genRoundKeys(_nonce);
      _nonce = _generateNonce();
      BigInt encryptedCounter = kuz.encryptCTR(_nonce, keys);
      List<int> encryptedBytes = _bigIntToBytes(encryptedCounter);

      int bytesToTake = min(remainingLength, encryptedBytes.length);
      randomBytes.addAll(encryptedBytes.sublist(0, bytesToTake));
      remainingLength -= bytesToTake;
    }

    // print(_bytesToBigInt(Uint8List.fromList(randomBytes), length * 8));
    return _bytesToBigInt(Uint8List.fromList(randomBytes), length * 8);
  }
}

void main() {
  KuznechikRand rand = KuznechikRand();

  BigInt randomBytes = rand.generateRandomBytes(256);
  print('Случайные байты:');
  print(randomBytes);
}
