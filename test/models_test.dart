// Testes unitários: modelos e lógica de cores do repositório
// (sem dependência de widgets/banco — sqflite não roda em widget tests).
import 'package:flutter_test/flutter_test.dart';

import 'package:to_do_flutter/models.dart';
import 'package:to_do_flutter/todo_repository.dart';

void main() {
  group('Task', () {
    test('fromMap/toMap fazem round-trip completo', () {
      final task = Task(
        id: 42,
        title: 'Título',
        description: 'Descrição',
        completed: true,
        dueDateTime: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1690000000000),
        categoryId: 7,
      );
      final restored = Task.fromMap(task.toMap());
      expect(restored.id, 42);
      expect(restored.title, 'Título');
      expect(restored.description, 'Descrição');
      expect(restored.completed, isTrue);
      expect(restored.dueDateTime, task.dueDateTime);
      expect(restored.createdAt, task.createdAt);
      expect(restored.categoryId, 7);
    });

    test('description ausente vira string vazia; completed default é int', () {
      final restored = Task.fromMap({
        'id': 1,
        'title': 'A',
        'completed': 0,
        'createdAt': 1690000000000,
      });
      expect(restored.description, '');
      expect(restored.completed, isFalse);
      expect(restored.dueDateTime, isNull);
      expect(restored.categoryId, isNull);
    });

    test('copyWith preserva campos não alterados', () {
      final task = Task(
        id: 1,
        title: 'A',
        description: 'D',
        completed: false,
        dueDateTime: null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1690000000000),
        categoryId: 3,
      );
      final updated = task.copyWith(completed: true, title: 'B');
      expect(updated.title, 'B');
      expect(updated.completed, isTrue);
      expect(updated.description, 'D');
      expect(updated.categoryId, 3);
      expect(updated.id, 1);
    });
  });

  group('Category / paleta', () {
    test('notificationIdFor é determinístico e 1:1', () {
      expect(TodoRepository.notificationIdFor(1),
          TodoRepository.notificationIdFor(1));
      expect(TodoRepository.notificationIdFor(1),
          isNot(TodoRepository.notificationIdFor(2)));
    });

    test('paleta de categorias tem cores distintas', () {
      expect(TodoRepository.categoryColors.toSet().length,
          TodoRepository.categoryColors.length);
    });

    test('Category.fromMap aceita cor ausente (fallback)', () {
      final c = Category.fromMap({'id': 1, 'name': 'X'});
      expect(c.color, '#607D8B');
    });
  });
}
