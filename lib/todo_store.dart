import 'package:flutter/foundation.dart' hide Category;

import 'models.dart';
import 'todo_notifier.dart';
import 'todo_repository.dart';

/// Estado global em ChangeNotifier (provider): a UI escuta via ListenableBuilder.
/// Toda escrita chama refresh() → notifyListeners() → telas recarregam do banco.
class TodoStore extends ChangeNotifier {
  TodoStore(this._repository, this._notifier);

  final TodoRepository _repository;
  final TodoNotifier _notifier;

  List<TaskWithCategory> _tasks = [];
  List<Category> _categories = [];
  TaskFilter _filter = TaskFilter.all;
  int? _categoryFilter;
  bool _loading = true;

  List<TaskWithCategory> get tasks => _filtered;
  List<Category> get categories => _categories;
  TaskFilter get filter => _filter;
  int? get categoryFilter => _categoryFilter;
  bool get loading => _loading;

  /// Acesso pontual a uma tarefa pelo editor (fora do ciclo de notificação).
  Future<Task?> repositoryTaskById(int id) => _repository.taskById(id);

  List<TaskWithCategory> get _filtered {
    Iterable<TaskWithCategory> result = _tasks;
    if (_filter == TaskFilter.pending) {
      result = result.where((t) => !t.task.completed);
    } else if (_filter == TaskFilter.completed) {
      result = result.where((t) => t.task.completed);
    }
    if (_categoryFilter != null) {
      result = result.where((t) => t.task.categoryId == _categoryFilter);
    }
    return result.toList();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final tasks = await _repository.allTasks();
    final cats = await _repository.allCategories();
    final catById = {for (final c in cats) c.id: c};
    _tasks = [
      for (final t in tasks) TaskWithCategory(t, t.categoryId == null ? null : catById[t.categoryId]),
    ];
    _categories = cats;
    _loading = false;
    notifyListeners();
  }

  void setFilter(TaskFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setCategoryFilter(int? categoryId) {
    _categoryFilter = categoryId;
    notifyListeners();
  }

  // ---- Task operations ----

  Future<void> toggleCompleted(Task task) async {
    final newCompleted = !task.completed;
    await _repository.setCompleted(task.id, newCompleted);
    if (newCompleted) {
      // Tarefa concluída: cancela o lembrete pendente.
      await _notifier.cancel(task.id);
    } else {
      // Reaberta: reagenda o lembrete se ainda não venceu.
      final due = task.dueDateTime;
      if (due != null && due.isAfter(DateTime.now())) {
        await _notifier.schedule(task.id, task.title, task.description, due);
      }
    }
    await load();
  }

  /// Cria ou edita. Retorna o id da tarefa. Agenda lembrete se vencimento futuro.
  Future<int?> saveTask({
    int? id,
    required String title,
    String description = '',
    DateTime? dueDateTime,
    int? categoryId,
  }) async {
    final due = dueDateTime;
    final scheduleReminder =
        due != null && due.isAfter(DateTime.now()) && _notifier.isAvailable;
    int taskId;
    if (id == null) {
      taskId = await _repository.insertTask(Task(
        id: 0,
        title: title,
        description: description,
        completed: false,
        dueDateTime: due,
        createdAt: DateTime.now(),
        categoryId: categoryId,
      ));
    } else {
      final existing = await _repository.taskById(id);
      if (existing == null) return null;
      taskId = id;
      // Vencimento mudou: cancela o lembrete antigo antes de reagendar.
      if (existing.dueDateTime != due) {
        await _notifier.cancel(taskId);
      }
      await _repository.updateTask(Task(
        id: existing.id,
        title: title,
        description: description,
        completed: existing.completed,
        dueDateTime: due,
        createdAt: existing.createdAt,
        categoryId: categoryId,
      ));
    }
    if (scheduleReminder) {
      await _notifier.schedule(taskId, title, description, due);
    }
    await load();
    return taskId;
  }

  Future<void> deleteTask(Task task) async {
    // Se houver lembrete agendado, cancela junto com a exclusão.
    await _notifier.cancel(task.id);
    await _repository.deleteTask(task.id);
    await load();
  }

  // ---- Category operations ----

  Future<void> addCategory(String name) async {
    if (name.trim().isEmpty) return;
    await _repository.insertCategory(
        Category(id: 0, name: name.trim(), color: '#607D8B'));
    await load();
  }

  Future<void> renameCategory(Category category, String name) async {
    if (name.trim().isEmpty || name.trim() == category.name) return;
    await _repository.updateCategory(category.copyWith(name: name.trim()));
    await load();
  }

  /// Política: ao excluir uma categoria em uso, as tarefas ficam sem categoria
  /// (ON DELETE SET NULL no esquema SQLite).
  Future<void> deleteCategory(Category category) async {
    await _repository.deleteCategory(category.id);
    if (_categoryFilter == category.id) {
      _categoryFilter = null;
    }
    await load();
  }
}

enum TaskFilter { all, pending, completed }
