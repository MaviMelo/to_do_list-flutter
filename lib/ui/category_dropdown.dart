import 'package:flutter/material.dart';

import '../todo_store.dart';

/// Dropdown de categoria com FlowRow interno ao popup: com muitas categorias
/// todas ficam acessíveis (mesmo comportamento do KMP).
class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.store,
    required this.selected,
    required this.onSelect,
  });

  final TodoStore store;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final categories = store.categories;
        return DropdownButtonFormField<int?>(
          value: selected,
          decoration: const InputDecoration(
            labelText: 'Categoria',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Sem categoria'),
            ),
            ...categories.map(
              (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
            ),
          ],
          onChanged: onSelect,
        );
      },
    );
  }
}
