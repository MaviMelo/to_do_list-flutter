import 'dart:math';

import 'models.dart';
import 'todo_database.dart';

/// Extensão local: copyWith para [Category] (o flutter/foundation exporta uma
/// anotação `Category` que colide no analyzer, mas o modelo é o de models.dart).
extension CategoryCopy on Category {
  Category copyWith({String? name, String? color}) => Category(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
      );
}

/// Camada de repositório sobre [TodoDatabase]: regras de negócio (IDs das
/// notificações, paleta de cores, preservação de createdAt) ficam aqui.
class TodoRepository {
  final TodoDatabase _database;

  TodoRepository(this._database);

  static const notificationIdBase = 100000;

  // Cores Material distintas; primeira não usada é escolhida ao criar categoria.
  static const categoryColors = [
    '#F44336', // vermelho
    '#E91E63', // rosa
    '#9C27B0', // roxo
    '#3F51B5', // índigo
    '#2196F3', // azul
    '#009688', // teal
    '#4CAF50', // verde
    '#FF9800', // laranja
    '#795548', // marrom
    '#607D8B', // blue grey
  ];

  /// id de notificação derivado do id da tarefa (1:1, determinístico).
  static int notificationIdFor(int taskId) => notificationIdBase + taskId;

  // ---- Tasks ----

  Future<List<Task>> allTasks() => _database.allTasks();

  Future<Task?> taskById(int id) => _database.taskById(id);

  Future<int> insertTask(Task task) async =>
      _database.insertTask(task.copyWith(createdAt: DateTime.now()));

  Future<int> updateTask(Task task) => _database.updateTask(task);

  Future<int> setCompleted(int id, bool completed) =>
      _database.setCompleted(id, completed);

  Future<int> deleteTask(int id) => _database.deleteTask(id);

  // ---- Categories ----

  Future<List<Category>> allCategories() => _database.allCategories();

  Future<Category?> categoryById(int id) => _database.categoryById(id);

  Future<int> insertCategory(Category category) async {
    final used = (await allCategories()).map((c) => c.color).toSet();
    final color = categoryColors.firstWhere(
          (c) => !used.contains(c),
          orElse: () => categoryColors[Random().nextInt(categoryColors.length)],
        );
    return _database.insertCategory(category.copyWith(color: color));
  }

  Future<int> updateCategory(Category category) =>
      _database.updateCategory(category);

  Future<int> deleteCategory(int id) => _database.deleteCategory(id);
}
