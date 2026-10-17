import 'package:money_management_app/domain/models/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getAllCategories({String? kind});
  Future<List<Category>> getAllCategoriesIncludingDeleted({String? kind});
  Future<Category?> getCategoryById(int id);
  Future<int> addCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<List<int>> deleteCategory(int id);
  Future<void> restoreCategory(int id);
  Future<bool> categoryHasExpenses(int id);
  Future<int> countTransactionsForCategory(int id);
  Future<int> countRemindersForCategory(int id);
}
