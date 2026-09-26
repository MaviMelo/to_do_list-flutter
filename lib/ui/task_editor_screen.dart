import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../todo_store.dart';
import 'category_dropdown.dart';

/// Tela 2: editor/criação de tarefas. Recebe apenas o taskId (null = criação)
/// e carrega o objeto do banco — estratégia documentada em BUILD_LOG.md.
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key, required this.store, this.taskId});

  final TodoStore store;
  final int? taskId;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  DateTime? _dueDateTime;
  int? _categoryId;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadExisting();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final taskId = widget.taskId;
    if (taskId == null) {
      setState(() => _loaded = true);
      return;
    }
    final task = await widget.store.repositoryTaskById(taskId);
    if (task == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _dueDateTime = task.dueDateTime;
      _categoryId = task.categoryId;
      _loaded = true;
    });
  }

  Future<void> _pickDueDateTime() async {
    final now = DateTime.now();
    final initialDate = _dueDateTime ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDateTime ?? date),
    );
    if (time == null) return;
    setState(() {
      _dueDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.store.saveTask(
      id: widget.taskId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDateTime: _dueDateTime,
      categoryId: _categoryId,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir tarefa'),
        content: const Text('Deseja realmente excluir esta tarefa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final task = await widget.store.repositoryTaskById(widget.taskId!);
    if (task == null) return;
    await widget.store.deleteTask(task);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId == null ? 'Nova tarefa' : 'Editar tarefa'),
        actions: [
          if (widget.taskId != null)
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete),
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Informe um título'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  CategoryDropdown(
                    store: widget.store,
                    selected: _categoryId,
                    onSelect: (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDueDateTime,
                          icon: const Icon(Icons.schedule),
                          label: Text(_dueDateTime == null
                              ? 'Vencimento'
                              : _dateFormat.format(_dueDateTime!)),
                        ),
                      ),
                      if (_dueDateTime != null)
                        IconButton(
                          tooltip: 'Remover vencimento',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _dueDateTime = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar'),
                  ),
                ],
              ),
            ),
    );
  }
}
