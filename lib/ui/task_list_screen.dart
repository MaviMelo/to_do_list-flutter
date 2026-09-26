import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../todo_store.dart';
import 'app.dart';

/// Tela 1: lista de tarefas com filtros por status e categoria.
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key, required this.store});

  final TodoStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas tarefas'),
        actions: [
          IconButton(
            tooltip: 'Categorias',
            icon: const Icon(Icons.category),
            onPressed: () => openCategories(context, store),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final tasks = store.tasks;
          if (store.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (tasks.isEmpty) {
            return const Center(child: Text('Nenhuma tarefa encontrada.'));
          }
          return RefreshIndicator(
            onRefresh: store.load,
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) => TaskRow(
                item: tasks[index],
                onToggle: () => store.toggleCompleted(tasks[index].task),
                onOpen: () => openTaskEditor(context, store,
                    taskId: tasks[index].task.id),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openTaskEditor(context, store),
        tooltip: 'Nova tarefa',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onOpen,
  });

  final TaskWithCategory item;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final category = item.category;
    final overdue = task.dueDateTime != null &&
        !task.completed &&
        task.dueDateTime!.isBefore(DateTime.now());
    return ListTile(
      leading: Checkbox(
        value: task.completed,
        onChanged: (_) => onToggle(),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.completed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Row(
        children: [
          if (category != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _colorFromHex(category.color),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(category.name),
            const SizedBox(width: 8),
          ],
          if (task.dueDateTime != null)
            Text(
              _dateFormat.format(task.dueDateTime!),
              style: TextStyle(color: overdue ? Colors.red : null),
            ),
        ],
      ),
      onTap: onOpen,
    );
  }
}

Color _colorFromHex(String hex) {
  final value = hex.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return Colors.grey;
  return Color(0xFF000000 | parsed);
}
