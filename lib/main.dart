import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'data/database.dart';

// Create a global instance of the database (for simplicity in this simple example)
final database = AppDatabase();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Database Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _addTodo() async {
    final title = _controller.text;
    if (title.isNotEmpty) {
      await database.insertTodoItem(
        TodoItemsCompanion(
          title: drift.Value(title),
          description: const drift.Value('Created via app'),
        ),
      );
      _controller.clear();
    }
  }

  Future<void> _deleteTodo(TodoItem item) async {
    await database.deleteTodoItem(item);
  }

  Future<void> _toggleComplete(TodoItem item) async {
    await database.updateTodoItem(
      item.copyWith(isCompleted: !item.isCompleted),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drift SQLite CRUD'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            tooltip: 'Run Custom SQL (Completed)',
            onPressed: () async {
              final completed = await database.getCompletedTodosCustomSql();
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Custom SQL Result'),
                    content: Text(
                      'Found ${completed.length} completed items via raw SQL:\n\n' +
                          completed.map((e) => '- ${e.title}').join('\n'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter task name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(onPressed: _addTodo, icon: const Icon(Icons.add)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TodoItem>>(
              stream: database.watchAllTodoItems(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final items = snapshot.data!;
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(
                          item.title,
                          style: TextStyle(
                            decoration: item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(item.description ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: item.isCompleted,
                              onChanged: (_) => _toggleComplete(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteTodo(item),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
