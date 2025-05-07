import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sortyfiy_stats.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE statistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scans INTEGER NOT NULL DEFAULT 0,
        found_items INTEGER NOT NULL DEFAULT 0,
        recognized_packaging INTEGER NOT NULL DEFAULT 0,
        not_recognized_packaging INTEGER NOT NULL DEFAULT 0,
        recommended_disposals INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Initiale Werte einfügen
    await db.insert('statistics', {
      'scans': 0,
      'found_items': 0,
      'recognized_packaging': 0,
      'not_recognized_packaging': 0,
      'recommended_disposals': 0,
    });
  }

  Future<void> incrementScan() async {
    final db = await instance.database;
    await db.rawUpdate('UPDATE statistics SET scans = scans + 1');
  }

  Future<void> incrementFoundItems() async {
    final db = await instance.database;
    await db.rawUpdate('UPDATE statistics SET found_items = found_items + 1');
  }

  Future<void> incrementRecognizedPackaging() async {
    final db = await instance.database;
    await db.rawUpdate(
        'UPDATE statistics SET recognized_packaging = recognized_packaging + 1');
  }

  Future<void> incrementNotRecognizedPackaging() async {
    final db = await instance.database;
    await db.rawUpdate(
        'UPDATE statistics SET not_recognized_packaging = not_recognized_packaging + 1');
  }

  Future<void> incrementRecommendedDisposals() async {
    final db = await instance.database;
    await db.rawUpdate(
        'UPDATE statistics SET recommended_disposals = recommended_disposals + 1');
  }

  Future<Map<String, int>> getStatistics() async {
    final db = await instance.database;
    final result = await db.query('statistics');

    if (result.isNotEmpty) {
      return {
        'scans': result.first['scans'] as int,
        'found_items': result.first['found_items'] as int,
        'recognized_packaging': result.first['recognized_packaging'] as int,
        'not_recognized_packaging':
            result.first['not_recognized_packaging'] as int,
        'recommended_disposals': result.first['recommended_disposals'] as int,
      };
    } else {
      return {
        'scans': 0,
        'found_items': 0,
        'recognized_packaging': 0,
        'not_recognized_packaging': 0,
        'recommended_disposals': 0
      };
    }
  }

  Future<void> resetStatistics() async {
    final db = await instance.database;
    await db.update(
      'statistics',
      {
        'scans': 0,
        'found_items': 0,
        'recognized_packaging': 0,
        'not_recognized_packaging': 0,
        'recommended_disposals': 0
      },
    );
  }
}
