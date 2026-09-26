import 'package:flutter/material.dart';

import '../todo_store.dart';
import 'categories_screen.dart';
import 'task_editor_screen.dart';
import 'task_list_screen.dart';

/// Navegação imperativa via Navigator.push (Material PageRoute). A tela
/// editors recebe apenas o id da tarefa (e o objeto recarregado do banco
/// pelo editor), decidido em BUILD_LOG.md Entrada 03.
class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.store});

  final TodoStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: TaskListScreen(store: store),
    );
  }
}

/// Abre o editor em modo criação (taskId == null) ou edição (taskId != null).
void openTaskEditor(BuildContext context, TodoStore store, {int? taskId}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TaskEditorScreen(store: store, taskId: taskId),
    ),
  );
}

void openCategories(BuildContext context, TodoStore store) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CategoriesScreen(store: store)),
  );
}
