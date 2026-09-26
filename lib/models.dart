class Task {
  final int id;
  final String title;
  final String description;
  final bool completed;
  final DateTime? dueDateTime;
  final DateTime createdAt;
  final int? categoryId;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
    required this.dueDateTime,
    required this.createdAt,
    required this.categoryId,
  });

  factory Task.fromMap(Map<String, Object?> map) => Task(
        id: map['id'] as int,
        title: map['title'] as String,
        description: (map['description'] as String?) ?? '',
        completed: (map['completed'] as int) == 1,
        dueDateTime: map['dueDateTime'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['dueDateTime'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        categoryId: map['categoryId'] as int?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'completed': completed ? 1 : 0,
        'dueDateTime': dueDateTime?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'categoryId': categoryId,
      };

  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? completed,
    DateTime? dueDateTime,
    DateTime? createdAt,
    int? categoryId,
  }) =>
      Task(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        completed: completed ?? this.completed,
        dueDateTime: dueDateTime ?? this.dueDateTime,
        createdAt: createdAt ?? this.createdAt,
        categoryId: categoryId ?? this.categoryId,
      );
}

class TaskWithCategory {
  final Task task;
  final Category? category;

  const TaskWithCategory(this.task, this.category);
}

class Category {
  final int id;
  final String name;
  final String color;

  const Category({
    required this.id,
    required this.name,
    required this.color,
  });

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int,
        name: map['name'] as String,
        color: (map['color'] as String?) ?? '#607D8B',
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': color,
      };
}
