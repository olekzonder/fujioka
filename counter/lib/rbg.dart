import 'dart:math';

class RNG {
  static BigInt randomBitGenerator(int numBits) {
    Random random = Random(DateTime.now().microsecondsSinceEpoch);
    int numBytes = (numBits / 8).ceil();

    List<int> bytes = List.generate(numBytes, (_) => random.nextInt(256));
    bytes[numBytes - 1] &= ((1 << (numBits % 8)) - 1);
    String hexString =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return BigInt.parse(hexString, radix: 16);
  }
}

void main() {
  print(RNG.randomBitGenerator(1024));
}
