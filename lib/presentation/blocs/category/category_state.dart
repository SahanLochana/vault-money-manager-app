import 'package:money_management_app/domain/models/category.dart';

abstract class CategoryState {
  const CategoryState();
}

class CategoryInitial extends CategoryState {
  const CategoryInitial();
}

class CategoryLoading extends CategoryState {
  const CategoryLoading();
}

class CategoryLoaded extends CategoryState {
  final List<Category> categories;
  const CategoryLoaded(this.categories);

  List<Category> get expenseCategories =>
      categories.where((c) => c.kind == CategoryKind.expense).toList();
  List<Category> get incomeCategories =>
      categories.where((c) => c.kind == CategoryKind.income).toList();
}

class CategoryError extends CategoryState {
  final String message;
  const CategoryError(this.message);
}
