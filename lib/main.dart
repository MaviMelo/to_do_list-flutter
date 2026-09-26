import 'package:flutter/material.dart';

import 'todo_database.dart';
import 'todo_notifier.dart';
import 'todo_repository.dart';
import 'todo_store.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = TodoDatabase();
  final repository = TodoRepository(database);
  final notifier = TodoNotifier();
  await notifier.init();
  await notifier.requestPermission();

  final store = TodoStore(repository, notifier);
  await store.load();

  runApp(TodoApp(store: store));
}
