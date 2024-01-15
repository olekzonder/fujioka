import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';

import 'random.dart';

class Prime {
  static BigInt _sqrt(BigInt n) {
    BigInt x = n;
    BigInt y = (x + (n ~/ x)) >> 1;
    while (y < x) {
      x = y;
      y = (x + (n ~/ x)) >> 1;
    }
    return x;
  }

  static BigInt gcd(BigInt a, BigInt b) {
    while (b != BigInt.zero) {
      var temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }

  static bool _isPerfectSquare(BigInt n) {
    BigInt sqrtN = _sqrt(n);
    return sqrtN * sqrtN == n;
  }

  static BigInt _jacobiSymbol(BigInt a, BigInt n) {
    a = a % n;
    if (a == BigInt.one || n == BigInt.one) {
      return BigInt.one;
    }
    if (a == BigInt.zero) {
      return BigInt.zero;
    }
    int e = 0;
    BigInt a1 = a;
    while (a1.isEven) {
      e++;
      a1 = a1 >> 1;
    }
    BigInt s = BigInt.one;
    if (e.isEven ||
        n % BigInt.from(8) == BigInt.one ||
        n % BigInt.from(8) == BigInt.from(7)) {
      s = BigInt.one;
    } else if (n % BigInt.from(4) == BigInt.from(3) ||
        n % BigInt.from(8) == BigInt.from(5)) {
      s = -BigInt.one;
    }

    if (n % BigInt.from(4) == BigInt.from(3) &&
        a1 % BigInt.from(4) == BigInt.from(3)) {
      s = -s;
    }
    BigInt n1 = n % a1;
    return s * _jacobiSymbol(n1, a1);
  }

// Реализация теста на простоту Миллера-Рабина
// входы:
// w - тестируемое на простоту число
// iterations - число проводимых тестов
//число проводимых тестов указано в таблице C.1 стандарта FIPS.186-4
// выходы:
// false, если число является составным
// true, если число является вероятно простым
  static bool testMillerRabin(BigInt w, int iterations) {
    if (w.isEven) {
      return false;
    }
    BigInt m = w - BigInt.one; // (шаг 2)
    int a = 0;
    while (m.isEven) {
      m = m >> 1;
      a++; // нахождение НОД (w-1;2^a) (шаг 1)
    }
    int wlen = w.bitLength; // (шаг 3)
    for (int i = 0; i < iterations; i++) {
      // нахождение числа b такого, что выполняется условие:
      // 1 < b < w-1
      BigInt b = BigInt.from(0);
      do {
        b = KuznechikRand().generateRandomBytes(wlen ~/ 8);
      } while (b >= w);

      //z = b^m mod w
      BigInt z = b.modPow(m, w);

      if (z == BigInt.one || z == w - BigInt.one) {
        continue;
      }

      // цикл 4.5
      for (int j = 0; j < a - 1; j++) {
        z = z.modPow(BigInt.two, w);
        if (z == w - BigInt.one) {
          break;
        }

        if (z == BigInt.one) {
          return false;
        }
      }

      if (z != w - BigInt.one) {
        return false;
      }
    }

    return true;
  }

// Реализация теста на простоту Люка
// Входы:
// c -- тестируемое число
// Выходы:
// true, если число вероятно простое
// false, если число составное
  static bool testLucas(BigInt c) {
    if (_isPerfectSquare(c)) {
      return false;
    }
    // Нахождение первого символа Якоби для числа c из последовательности {5, –7, 9, –11, 13, –15, 17, ...}, равного -1.
    int d = -3;
    int iter = 2;
    int mul = 1;
    BigInt dc = BigInt.zero;
    while (dc != BigInt.from(-1)) {
      d = mul * (iter * 2 - 1);
      dc = _jacobiSymbol(BigInt.from(d), c);
      if (dc == BigInt.zero) {
        return false;
      }
      iter++;
      if (iter.isOdd) {
        mul = -1;
      } else {
        mul = 1;
      }
    }
    // K = C+1
    BigInt k = c + BigInt.one;
    BigInt u = BigInt.one;
    BigInt v = BigInt.one;
    // Разбиение числа K на биты
    String binaryK = k.toRadixString(2).substring(1);
    int r = binaryK.length;
    for (int i = 0; i < r; i++) {
      BigInt uTemp = (u * v).remainder(c);
      BigInt vTemp = v * v + BigInt.from(d) * u * u;
      vTemp = (vTemp * (c + BigInt.one) ~/ (BigInt.two)).remainder(c);
      if (binaryK[i] == '1') {
        u = uTemp + vTemp;
        u = (u * (c + BigInt.one) ~/ (BigInt.two)).remainder(c);
        v = vTemp + BigInt.from(d) * uTemp;
        v = (v * (c + BigInt.one) ~/ (BigInt.two)).remainder(c);
      } else {
        u = uTemp;
        v = vTemp;
      }
    }
    return u == BigInt.zero;
  }

  static BigInt moduloInverse(BigInt a, BigInt s, BigInt p) {
    if (p == BigInt.zero) {
      throw Exception('p cannot be zero');
    }

    if (s == BigInt.zero) {
      return BigInt.one;
    }

    if (s.isNegative) {
      throw Exception('s cannot be negative');
    }

    BigInt v = BigInt.one;
    while (s > BigInt.zero) {
      if (s.isOdd) {
        v = (v * a) % p;
      }
      a = (a * a) % p;
      s = s >> 1;
    }

    return v.modInverse(p);
  }
}
