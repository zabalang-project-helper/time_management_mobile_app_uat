import 'package:flutter/foundation.dart' hide Category;
import 'package:drift/drift.dart';
import '../data/database.dart';

/// ViewModel for managing categories
class CategoryViewModel extends ChangeNotifier {
  final AppDatabase _db;

  CategoryViewModel(this._db);

  Stream<List<Category>> get categories => _db.watchAllCategories();

  Future<void> addCategory({
    required String name,
    required int color,
    required String note,
  }) async {
    await _db.insertCategory(
      CategoriesCompanion(
        name: Value(name),
        color: Value(color),
        note: Value(note),
      ),
    );
    notifyListeners();
  }

  Future<void> updateCategory(Category category) async {
    await _db.updateCategory(category);
    notifyListeners();
  }

  Future<void> deleteCategory(Category category) async {
    await _db.deleteCategory(category);
    notifyListeners();
  }
}
