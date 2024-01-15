import 'dart:io';

class Log {
  static final Log _instance = Log._internal();

  factory Log() {
    return _instance;
  }
  var outputFile = File(
      'log-${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}-${DateTime.now().hour}-${DateTime.now().minute}-${DateTime.now().second}.txt');
  void log(String message) {
    print(message);
    var now = new DateTime.now().toUtc();
    outputFile.writeAsStringSync("$now | $message\n", mode: FileMode.append);
  }

  Log._internal();
}
