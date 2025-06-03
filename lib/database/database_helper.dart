import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'conexa.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY,
        path TEXT
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getDocuments() async {
    Database db = await database;
    return await db.query('documents');
  }

  Future<int> insertDocument(String path) async {
    Database db = await database;
    return await db.insert('documents', {'path': path});
  }

  Future<int> deleteDocument(int id) async {
    Database db = await database;
    return await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }
}
