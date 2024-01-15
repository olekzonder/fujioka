import 'dart:async';
import 'dart:isolate';
import 'package:registrar/crypto/schnorr.dart';
import 'package:registrar/log.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  final StreamController<Map<int, List<String>>> _databaseStreamController =
      StreamController<Map<int, List<String>>>();
  Stream<Map<int, List<String>>> get databaseStream =>
      _databaseStreamController.stream;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  late Database _database;
  Map<int, List<String>> _voters = {};
  Future<void> open() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'db.sqlite');
    Log().log('Путь до каталога с БД: ${path.toString()}');
    _database = await databaseFactory.openDatabase(path);
    await _createTables();
  }

  Future<void> _createTables() async {
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS key (
        p TEXT,
        q TEXT,
        g TEXT,
        x TEXT,
        y TEXT
      )
    ''');

    final keys = await _database.rawQuery('''SELECT * FROM key''');
    if (keys.isEmpty) await _generateKeys();

    await _database.execute('''
      CREATE TABLE IF NOT EXISTS voters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fio TEXT,
        y TEXT
      )
    ''');

    final result = await _database.rawQuery('''SELECT id,fio,y FROM voters''');
    for (var row in result) {
      int id = int.parse(row['id'].toString());
      String fio = row['fio'].toString();
      String y = row['y'].toString();
      _voters[id] = [fio, y];
    }
    _databaseStreamController.add(_voters);
  }

  void getVoters() {
    _databaseStreamController.add(_voters);
  }

  Future<void> _generateKeys() async {
    var keys = await Isolate.run(Schnorr.generate);
    var q = keys[0].toString();
    var p = keys[1].toString();
    var g = keys[2].toString();
    var x = keys[3].toString();
    var y = keys[4].toString();
    await _database.rawInsert('''
      INSERT INTO key (q,p,g,x,y) 
      VALUES (?,?,?,?,?)
    ''', [
      q,
      p,
      g,
      x,
      y,
    ]);
  }

  Future<void> addUser(String fio, String pubkey) async {
    await _database.rawInsert('''
      INSERT INTO voters (fio, y)
      VALUES (?, ?)
    ''', [fio, pubkey]);
    final result = await _database
        .rawQuery('''SELECT id,fio,y FROM voters where y = ?''', [pubkey]);
    for (var row in result) {
      int id = int.parse(row['id'].toString());
      String fio = row['fio'].toString();
      String y = row['y'].toString();
      _voters[id] = [fio, y];
    }
    _databaseStreamController.add(_voters);
  }

  Future<List<BigInt>> getKeys() async {
    final keys = await _database.rawQuery('''SELECT * FROM key''');
    var p = BigInt.parse(keys.first['p'].toString());
    var q = BigInt.parse(keys.first['q'].toString());
    var g = BigInt.parse(keys.first['g'].toString());
    var x = BigInt.parse(keys.first['x'].toString());
    var y = BigInt.parse(keys.first['y'].toString());
    Log().log('Простое число q = $q');
    Log().log('Простое число p = $p');
    Log().log('Число g = $g');
    Log().log('Закрытый ключ сервера x = $x');
    Log().log('Открытый ключ сервера y = $y');
    return [q, p, g, x, y];
  }

  Future<int> checkUser(String pubkey) async {
    final result = await _database.rawQuery('''
      SELECT id
      FROM voters
      WHERE y = ?
    ''', [pubkey]);
    return result.isNotEmpty ? int.parse(result.first['id'].toString()) : -1;
  }

  Future<void> resetTables() async {
    await _database.delete('key');
    await _database.delete('voters');
    await _createTables();
  }

  Future<String> getFio(id) async {
    final result = await _database
        .rawQuery('''SELECT fio FROM voters where id = ?''', [id]);
    return result.isNotEmpty ? result.first['fio'].toString() : 'not found';
  }

  Future<void> removeUser(id) async {
    await _database.rawDelete('''DELETE FROM voters where id = ?''', [id]);
    _voters.remove(id);
    _databaseStreamController.add(_voters);
  }

  Future<void> close() async {
    await _database.close();
  }
}
