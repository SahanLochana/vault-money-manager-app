import 'package:money_management_app/data/datasources/category_local_datasource.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryLocalDatasource localDatasource;

  CategoryRepositoryImpl({required this.localDatasource});

  @override
  Future<List<Category>> getAllCategories({String? kind}) async {
    return await localDatasource.getAllCategories(kind: kind);
  }

  @override
  Future<List<Category>> getAllCategoriesIncludingDeleted({String? kind}) async {
    return await localDatasource.getAllCategoriesIncludingDeleted(kind: kind);
  }

  @override
  Future<Category?> getCategoryById(int id) async {
    return await localDatasource.getCategoryById(id);
  }

  @override
  Future<int> addCategory(Category category) async {
    return await localDatasource.insertCategory(category);
  }

  @override
  Future<void> updateCategory(Category category) async {
    await localDatasource.updateCategory(category);
  }

  @override
  Future<List<int>> deleteCategory(int id) async {
    return await localDatasource.deleteCategory(id);
  }

  @override
  Future<void> restoreCategory(int id) async {
    await localDatasource.restoreCategory(id);
  }

  @override
  Future<bool> categoryHasExpenses(int id) async {
    return await localDatasource.categoryHasExpenses(id);
  }

  @override
  Future<int> countTransactionsForCategory(int id) async {
    return await localDatasource.countTransactionsForCategory(id);
  }

  @override
  Future<int> countRemindersForCategory(int id) async {
    return await localDatasource.countRemindersForCategory(id);
  }
}
