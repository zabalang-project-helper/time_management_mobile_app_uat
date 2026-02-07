import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:time_management_mobile_app/data/database.dart';

class AddCategoryDialog extends StatefulWidget {
  final Category? existingCategory;
  final Function(List<CategoriesCompanion>) onSave;

  const AddCategoryDialog({
    super.key,
    this.existingCategory,
    required this.onSave,
  });

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {

  late TextEditingController _nameController;
  late TextEditingController _noteController;
  late Color _selectedColor;

  final List<Color> _colorOptions = [
    const Color(0xFF2196F3), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFFF44336), // Red
    const Color(0xFFFF9800), // Orange
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFFE91E63), // Pink
    const Color(0xFF607D8B), // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.existingCategory;
    _nameController = TextEditingController(text: c?.name ?? '');
    _noteController = TextEditingController(text: c?.note ?? '');
    _selectedColor = c != null ? Color(c.color) : const Color(0xFF2196F3);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existingCategory != null ? "Edit Category" : "Add Category",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Category Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: "Note (optional)",
                hintText: 'Add more details...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Color Picker
            const Text(
              'Color',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: _colorOptions.map((color) {
                final isSelected =
                    _selectedColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveCategory,
                child: const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCategory() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a category name")),
      );
      return;
    }

    final category = CategoriesCompanion(
      name: drift.Value(name),
      note: drift.Value(        
        _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim()
      ),
      color: drift.Value(_selectedColor.toARGB32()),
    );

    widget.onSave([category]);
    Navigator.of(context).pop();
  }
}
