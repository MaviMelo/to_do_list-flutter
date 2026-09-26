import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// SQLite direto (sem ORM): banco criado em getDatabasesPath() com as tabelas
/// Category e Task; CRUD via SQL nomeado nos métodos desta classe.
class TodoDatabase {
  static const _dbName = 'todo.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dbName),
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Category (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE Task (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            completed INTEGER NOT NULL DEFAULT 0,
            dueDateTime INTEGER,
            createdAt INTEGER NOT NULL,
            categoryId INTEGER,
            FOREIGN KEY (categoryId) REFERENCES Category (id) ON DELETE SET NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_task_category ON Task (categoryId)');
      },
    );
  }

  // ---- Tasks ----

  Future<List<Task>> allTasks() async {
    final db = await database;
    final rows = await db.query('Task', orderBy: 'completed ASC, dueDateTime IS NULL, dueDateTime ASC, createdAt DESC');
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> taskById(int id) async {
    final db = await database;
    final rows = await db.query('Task', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Task.fromMap(rows.first);
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return db.insert('Task', task.toMap()..remove('id'));
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return db.update('Task', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> setCompleted(int id, bool completed) async {
    final db = await database;
    return db.update('Task', {'completed': completed ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return db.delete('Task', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Categories ----

  Future<List<Category>> allCategories() async {
    final db = await database;
    final rows = await db.query('Category', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<Category?> categoryById(int id) async {
    final db = await database;
    final rows = await db.query('Category', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Category.fromMap(rows.first);
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return db.insert('Category', category.toMap()..remove('id'));
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return db.update('Category', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.delete('Category', where: 'id = ?', whereArgs: [id]);
  }
}
