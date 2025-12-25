import 'package:flutter/material.dart';

import '../data/todo_service.dart';

class TodayTodosScreen extends StatefulWidget {
  const TodayTodosScreen({super.key});

  @override
  State<TodayTodosScreen> createState() => _TodayTodosScreenState();
}

class _TodayTodosScreenState extends State<TodayTodosScreen> {
  final TodoService _todoService = TodoService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _todos = [];

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final todos = await _todoService.fetchTodayTodos();
      if (!mounted) {
        return;
      }
      setState(() {
        _todos = todos;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTodo(Map<String, dynamic> todo, bool? value) async {
    final id = todo['id']?.toString();
    if (id == null) {
      return;
    }
    final done = value ?? false;

    setState(() {
      todo['is_done'] = done;
    });

    try {
      await _todoService.setTodoDone(id, done);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final total = _todos.length;
    final completed =
        _todos.where((item) => item['is_done'] == true).length;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      appBar: AppBar(title: const Text('Today Tasks')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Completed: $completed / $total'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _todos.isEmpty
                        ? const Center(child: Text('No tasks yet.'))
                        : ListView.builder(
                            itemCount: _todos.length,
                            itemBuilder: (context, index) {
                              final todo = _todos[index];
                              final title = todo['title']?.toString() ?? '';
                              final done = todo['is_done'] == true;
                              return CheckboxListTile(
                                title: Text(title),
                                value: done,
                                onChanged: (value) =>
                                    _toggleTodo(todo, value),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
