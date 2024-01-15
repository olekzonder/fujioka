import 'dart:typed_data';
import 'package:convert/convert.dart';

import 'random.dart';

void main() {
  Kuznechik kuz = Kuznechik();
  BigInt key = BigInt.zero;
  while (key.bitLength < 255) {
    key = KuznechikRand().generateRandomBytes(32);
  }
  List<BigInt> keys = kuz.genRoundKeys(key);
  print("Итерационные ключи:");
  for (var key in keys) {
    print(kuz.formatBigInt(key));
  }
  BigInt data = BigInt.one;
  print('Открытое сообщение');
  print(kuz.formatBigInt(data));
  print(data.bitLength);
  BigInt encryptedData = kuz.encrypt(data, keys);
  print('Зашифрованное сообщение');
  print(kuz.formatBigInt(encryptedData));
  print(encryptedData);
  BigInt decryptedData = kuz.decrypt(encryptedData, keys);
  print('Расшифрованное сообщение');
  print(kuz.formatBigInt(decryptedData));
}

class Kuznechik {
  final _blockSize = 16;

  BigInt genKey() {
    BigInt key = BigInt.zero;
    while (key.bitLength < 255) {
      key = KuznechikRand().generateRandomBytes(32);
    }
    return key;
  }

  Uint8List bigIntToBytes(BigInt number) {
    String string = number.toRadixString(16);
    var byteCount = (string.length + 1) ~/ 2;
    var uint8List = Uint8List(byteCount);

    if (string.length < 32) {
      string = '0' * (32 - string.length) + string;
    }
    if (string.length == 63) {
      string = '0' + string;
    }
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

  BigInt bytesToBigInt(Uint8List bytes) {
    String hexString = hex.encode(bytes);
    return BigInt.parse(hexString, radix: 16).toUnsigned(128);
  }

  BigInt X(BigInt a, BigInt b) {
    BigInt x = (a ^ b).toUnsigned(128);
    return x;
  }

  BigInt S(BigInt number) {
    Uint8List bytes = bigIntToBytes(number);
    for (int i = 0; i < _blockSize; i++) {
      bytes[i] = Pi[bytes[i]];
    }
    return bytesToBigInt(bytes).toUnsigned(128);
  }

  BigInt S_reverse(BigInt number) {
    Uint8List bytes = bigIntToBytes(number);
    for (int i = 0; i < _blockSize; i++) {
      bytes[i] = Pi_reverse[bytes[i]];
    }
    return bytesToBigInt(bytes).toUnsigned(128);
  }

  int gfMult(int a, int b) {
    int c = 0;
    while (b != 0) {
      if ((b & 1) != 0) {
        c ^= a;
      }
      a = (a << 1) ^ ((a & 0x80) != 0 ? 0xC3 : 0x00);
      b >>= 1;
    }
    return c;
  }

  Uint8List R(Uint8List number) {
    // Счетчик
    int i;
    // Аккумулятор
    int acc = number[15];
    // Переход к представлению в байтах
    Uint8List byte = number;
    for (i = 14; i >= 0; i--) {
      byte[i + 1] = byte[i];
      acc ^= gfMult(byte[i], linearVector[i]);
    }
    byte[0] = acc;
    return byte;
  }

// Обратная функция R
  Uint8List R_reverse(Uint8List number) {
    // Счетчик
    int i;
    // Аккумулятор
    int acc = number[0];
    // Переход к представлению в байтах
    Uint8List byte = number;
    for (i = 0; i < 15; i++) {
      byte[i] = byte[i + 1];
      acc ^= gfMult(byte[i], linearVector[i]);
    }
    byte[15] = acc;
    return byte;
  }

// Функция L
  Uint8List L(Uint8List number) {
    Uint8List value = number;
    for (int i = 0; i < _blockSize; i++) {
      value = R(number);
    }
    return value;
  }

// Обратная функция L
  Uint8List L_reverse(Uint8List number) {
    Uint8List value = number;
    for (int i = 0; i < _blockSize; i++) {
      value = R_reverse(number);
    }
    return value;
  }

  List<BigInt> genRoundKeys(BigInt number) {
    Uint8List key = bigIntToBytes(number);
    List<BigInt> roundKeys = [];

    List<Uint8List> cs = List.generate(
        32, (index) => Uint8List.fromList(List.filled(_blockSize, 0)));
    for (int i = 0; i < 32; i++) {
      cs[i][15] = i + 1;
      cs[i] = L(cs[i]);
    }

    List<BigInt> ks = [BigInt.zero, BigInt.zero];
    // print(formatBigInt(bytesToBigInt(key)));
    // print(key.lengthInBytes);
    BigInt keyPart1 = bytesToBigInt(key.sublist(0, 16));
    BigInt keyPart2 = bytesToBigInt(key.sublist(16, 32));
    roundKeys.add(keyPart1);
    roundKeys.add(keyPart2);
    ks[0] = keyPart1;
    ks[1] = keyPart2;
    for (int i = 1; i <= 32; i++) {
      // print('Итерация $i');
      BigInt newKey = BigInt.zero;
      newKey = X(ks[0], bytesToBigInt(cs[i - 1]));
      // print(formatBigInt(newKey));
      newKey = S(newKey);
      // print(formatBigInt(newKey));
      newKey = bytesToBigInt(L(bigIntToBytes(newKey)));
      // print(formatBigInt(newKey));
      newKey = X(newKey, ks[1]);
      // print(formatBigInt(newKey));
      ks[1] = ks[0];
      ks[0] = newKey;
      if ((i > 0) && (i % 8 == 0)) {
        roundKeys.add(ks[0]);
        roundKeys.add(ks[1]);
      }
    }
    return roundKeys;
  }

  String formatBigInt(BigInt bigInt) {
    String hexString = bigInt.toRadixString(16).toUpperCase();
    List<String> bytes = [];

    if (hexString.length < 32) {
      hexString = '0' * (32 - hexString.length) + hexString;
    }

    for (int i = 0; i < hexString.length; i += 2) {
      bytes.add('0x${hexString.substring(i, i + 2)}');
    }

    return bytes.join(' ');
  }

  BigInt encrypt(BigInt message, List<BigInt> keys) {
    BigInt p = message;
    for (int i = 0; i < 10; i++) {
      p = X(p, keys[i]);
      if (i < 9) {
        p = S(p);
        p = bytesToBigInt(L(bigIntToBytes(p)));
      }
    }
    return p;
  }

  BigInt decrypt(BigInt message, List<BigInt> keys) {
    BigInt p = message;
    p = X(p, keys[9]);
    for (int i = 8; i >= 0; i--) {
      p = bytesToBigInt(L_reverse(bigIntToBytes(p)));
      p = S_reverse(p);
      p = X(p, keys[i]);
    }
    return p;
  }

  BigInt encryptCTR(BigInt counter, List<BigInt> keys) {
    BigInt p = counter;
    for (int i = 0; i < 10; i++) {
      p = X(p, keys[i]);
      if (i < 9) {
        p = S(p);
        p = bytesToBigInt(L(bigIntToBytes(p)));
      }
      p += BigInt.one;
      p = X(p, counter);
    }
    return p;
  }

  BigInt decryptCTR(BigInt counter, List<BigInt> keys) {
    BigInt p = counter;
    for (int i = 8; i >= 0; i--) {
      p = X(p, counter);
      p = bytesToBigInt(L_reverse(bigIntToBytes(p)));
      p = S_reverse(p);
      p = X(p, keys[i]);
    }
    p = X(p, keys[9]);
    return p;
  }

//Таблица прямого нелинейного преобразования
  final List<int> Pi = [
    0xFC,
    0xEE,
    0xDD,
    0x11,
    0xCF,
    0x6E,
    0x31,
    0x16,
    0xFB,
    0xC4,
    0xFA,
    0xDA,
    0x23,
    0xC5,
    0x04,
    0x4D,
    0xE9,
    0x77,
    0xF0,
    0xDB,
    0x93,
    0x2E,
    0x99,
    0xBA,
    0x17,
    0x36,
    0xF1,
    0xBB,
    0x14,
    0xCD,
    0x5F,
    0xC1,
    0xF9,
    0x18,
    0x65,
    0x5A,
    0xE2,
    0x5C,
    0xEF,
    0x21,
    0x81,
    0x1C,
    0x3C,
    0x42,
    0x8B,
    0x01,
    0x8E,
    0x4F,
    0x05,
    0x84,
    0x02,
    0xAE,
    0xE3,
    0x6A,
    0x8F,
    0xA0,
    0x06,
    0x0B,
    0xED,
    0x98,
    0x7F,
    0xD4,
    0xD3,
    0x1F,
    0xEB,
    0x34,
    0x2C,
    0x51,
    0xEA,
    0xC8,
    0x48,
    0xAB,
    0xF2,
    0x2A,
    0x68,
    0xA2,
    0xFD,
    0x3A,
    0xCE,
    0xCC,
    0xB5,
    0x70,
    0x0E,
    0x56,
    0x08,
    0x0C,
    0x76,
    0x12,
    0xBF,
    0x72,
    0x13,
    0x47,
    0x9C,
    0xB7,
    0x5D,
    0x87,
    0x15,
    0xA1,
    0x96,
    0x29,
    0x10,
    0x7B,
    0x9A,
    0xC7,
    0xF3,
    0x91,
    0x78,
    0x6F,
    0x9D,
    0x9E,
    0xB2,
    0xB1,
    0x32,
    0x75,
    0x19,
    0x3D,
    0xFF,
    0x35,
    0x8A,
    0x7E,
    0x6D,
    0x54,
    0xC6,
    0x80,
    0xC3,
    0xBD,
    0x0D,
    0x57,
    0xDF,
    0xF5,
    0x24,
    0xA9,
    0x3E,
    0xA8,
    0x43,
    0xC9,
    0xD7,
    0x79,
    0xD6,
    0xF6,
    0x7C,
    0x22,
    0xB9,
    0x03,
    0xE0,
    0x0F,
    0xEC,
    0xDE,
    0x7A,
    0x94,
    0xB0,
    0xBC,
    0xDC,
    0xE8,
    0x28,
    0x50,
    0x4E,
    0x33,
    0x0A,
    0x4A,
    0xA7,
    0x97,
    0x60,
    0x73,
    0x1E,
    0x00,
    0x62,
    0x44,
    0x1A,
    0xB8,
    0x38,
    0x82,
    0x64,
    0x9F,
    0x26,
    0x41,
    0xAD,
    0x45,
    0x46,
    0x92,
    0x27,
    0x5E,
    0x55,
    0x2F,
    0x8C,
    0xA3,
    0xA5,
    0x7D,
    0x69,
    0xD5,
    0x95,
    0x3B,
    0x07,
    0x58,
    0xB3,
    0x40,
    0x86,
    0xAC,
    0x1D,
    0xF7,
    0x30,
    0x37,
    0x6B,
    0xE4,
    0x88,
    0xD9,
    0xE7,
    0x89,
    0xE1,
    0x1B,
    0x83,
    0x49,
    0x4C,
    0x3F,
    0xF8,
    0xFE,
    0x8D,
    0x53,
    0xAA,
    0x90,
    0xCA,
    0xD8,
    0x85,
    0x61,
    0x20,
    0x71,
    0x67,
    0xA4,
    0x2D,
    0x2B,
    0x09,
    0x5B,
    0xCB,
    0x9B,
    0x25,
    0xD0,
    0xBE,
    0xE5,
    0x6C,
    0x52,
    0x59,
    0xA6,
    0x74,
    0xD2,
    0xE6,
    0xF4,
    0xB4,
    0xC0,
    0xD1,
    0x66,
    0xAF,
    0xC2,
    0x39,
    0x4B,
    0x63,
    0xB6
  ];
//Таблица обратного нелинейного преобрзования
  List<int> Pi_reverse = [
    0xA5,
    0x2D,
    0x32,
    0x8F,
    0x0E,
    0x30,
    0x38,
    0xC0,
    0x54,
    0xE6,
    0x9E,
    0x39,
    0x55,
    0x7E,
    0x52,
    0x91,
    0x64,
    0x03,
    0x57,
    0x5A,
    0x1C,
    0x60,
    0x07,
    0x18,
    0x21,
    0x72,
    0xA8,
    0xD1,
    0x29,
    0xC6,
    0xA4,
    0x3F,
    0xE0,
    0x27,
    0x8D,
    0x0C,
    0x82,
    0xEA,
    0xAE,
    0xB4,
    0x9A,
    0x63,
    0x49,
    0xE5,
    0x42,
    0xE4,
    0x15,
    0xB7,
    0xC8,
    0x06,
    0x70,
    0x9D,
    0x41,
    0x75,
    0x19,
    0xC9,
    0xAA,
    0xFC,
    0x4D,
    0xBF,
    0x2A,
    0x73,
    0x84,
    0xD5,
    0xC3,
    0xAF,
    0x2B,
    0x86,
    0xA7,
    0xB1,
    0xB2,
    0x5B,
    0x46,
    0xD3,
    0x9F,
    0xFD,
    0xD4,
    0x0F,
    0x9C,
    0x2F,
    0x9B,
    0x43,
    0xEF,
    0xD9,
    0x79,
    0xB6,
    0x53,
    0x7F,
    0xC1,
    0xF0,
    0x23,
    0xE7,
    0x25,
    0x5E,
    0xB5,
    0x1E,
    0xA2,
    0xDF,
    0xA6,
    0xFE,
    0xAC,
    0x22,
    0xF9,
    0xE2,
    0x4A,
    0xBC,
    0x35,
    0xCA,
    0xEE,
    0x78,
    0x05,
    0x6B,
    0x51,
    0xE1,
    0x59,
    0xA3,
    0xF2,
    0x71,
    0x56,
    0x11,
    0x6A,
    0x89,
    0x94,
    0x65,
    0x8C,
    0xBB,
    0x77,
    0x3C,
    0x7B,
    0x28,
    0xAB,
    0xD2,
    0x31,
    0xDE,
    0xC4,
    0x5F,
    0xCC,
    0xCF,
    0x76,
    0x2C,
    0xB8,
    0xD8,
    0x2E,
    0x36,
    0xDB,
    0x69,
    0xB3,
    0x14,
    0x95,
    0xBE,
    0x62,
    0xA1,
    0x3B,
    0x16,
    0x66,
    0xE9,
    0x5C,
    0x6C,
    0x6D,
    0xAD,
    0x37,
    0x61,
    0x4B,
    0xB9,
    0xE3,
    0xBA,
    0xF1,
    0xA0,
    0x85,
    0x83,
    0xDA,
    0x47,
    0xC5,
    0xB0,
    0x33,
    0xFA,
    0x96,
    0x6F,
    0x6E,
    0xC2,
    0xF6,
    0x50,
    0xFF,
    0x5D,
    0xA9,
    0x8E,
    0x17,
    0x1B,
    0x97,
    0x7D,
    0xEC,
    0x58,
    0xF7,
    0x1F,
    0xFB,
    0x7C,
    0x09,
    0x0D,
    0x7A,
    0x67,
    0x45,
    0x87,
    0xDC,
    0xE8,
    0x4F,
    0x1D,
    0x4E,
    0x04,
    0xEB,
    0xF8,
    0xF3,
    0x3E,
    0x3D,
    0xBD,
    0x8A,
    0x88,
    0xDD,
    0xCD,
    0x0B,
    0x13,
    0x98,
    0x02,
    0x93,
    0x80,
    0x90,
    0xD0,
    0x24,
    0x34,
    0xCB,
    0xED,
    0xF4,
    0xCE,
    0x99,
    0x10,
    0x44,
    0x40,
    0x92,
    0x3A,
    0x01,
    0x26,
    0x12,
    0x1A,
    0x48,
    0x68,
    0xF5,
    0x81,
    0x8B,
    0xC7,
    0xD6,
    0x20,
    0x0A,
    0x08,
    0x00,
    0x4C,
    0xD7,
    0x74
  ];

// Вектор линейного преобразования
  List<int> linearVector = [
    0x94,
    0x20,
    0x85,
    0x10,
    0xC2,
    0xC0,
    0x01,
    0xFB,
    0x01,
    0xC0,
    0xC2,
    0x10,
    0x85,
    0x20,
    0x94,
    0x01
  ];
}
