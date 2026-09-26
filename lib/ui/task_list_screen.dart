import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../todo_store.dart';
import 'app.dart';

/// Tela 1: lista de tarefas com filtros por status e categoria.
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key, required this.store});

  final TodoStore store;

  Future<void> _confirmExit(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair do aplicativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas tarefas'),
        actions: [
          TextButton.icon(
            onPressed: () => openCategories(context, store),
            icon: const Icon(Icons.category),
            label: const Text('Categorias'),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _confirmExit(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(store: store),
          Expanded(
            child: ListenableBuilder(
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openTaskEditor(context, store),
        tooltip: 'Nova tarefa',
        icon: const Icon(Icons.add),
        label: const Text('Nova tarefa'),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.store});

  final TodoStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final filter = store.filter;
        final categoryFilter = store.categoryFilter;
        final categories = store.categories;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  for (final f in TaskFilter.values) ...[
                    ChoiceChip(
                      label: Text(switch (f) {
                        TaskFilter.all => 'Todas',
                        TaskFilter.pending => 'Pendentes',
                        TaskFilter.completed => 'Concluídas',
                      }),
                      selected: filter == f,
                      onSelected: (_) => store.setFilter(f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            if (categories.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todas as categorias'),
                      avatar: categoryFilter == null
                          ? const Icon(Icons.check, size: 16)
                          : null,
                      selected: categoryFilter == null,
                      onSelected: (_) => store.setCategoryFilter(null),
                    ),
                    const SizedBox(width: 8),
                    for (final c in categories) ...[
                      ChoiceChip(
                        label: Text(c.name),
                        avatar: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colorFromHex(c.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        selected: categoryFilter == c.id,
                        onSelected: (_) => store.setCategoryFilter(c.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.description.isNotEmpty)
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          Row(
            children: [
              if (category != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colorFromHex(category.color),
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
        ],
      ),
      onTap: onOpen,
    );
  }
}

Color colorFromHex(String hex) {
  final value = hex.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return Colors.grey;
  return Color(0xFF000000 | parsed);
}
