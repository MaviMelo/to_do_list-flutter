import 'package:flutter/material.dart';

import '../models.dart';
import '../todo_store.dart';

/// Tela 3: gerenciamento de categorias (listar, criar, renomear, excluir).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, required this.store});

  final TodoStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final categories = store.categories;
          if (categories.isEmpty) {
            return const Center(child: Text('Nenhuma categoria criada.'));
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _colorFromHex(category.color),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(category.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Renomear',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _renameDialog(context, category),
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteDialog(context, category),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Nova categoria',
        onPressed: () => _addDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova categoria'),
      ),
    );
  }

  void _addDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              store.addCategory(controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _renameDialog(BuildContext context, Category category) {
    final controller = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              store.renameCategory(category, controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir categoria'),
        content: Text(
            'Excluir "${category.name}"? As tarefas desta categoria ficarão sem categoria.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              store.deleteCategory(category);
              Navigator.of(context).pop();
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

Color _colorFromHex(String hex) {
  final value = hex.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return Colors.grey;
  return Color(0xFF000000 | parsed);
}
