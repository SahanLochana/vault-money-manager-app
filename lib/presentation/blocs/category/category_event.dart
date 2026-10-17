import 'package:money_management_app/domain/models/category.dart';

abstract class CategoryEvent {
  const CategoryEvent();
}

class LoadCategoriesEvent extends CategoryEvent {
  const LoadCategoriesEvent();
}

class AddCategoryEvent extends CategoryEvent {
  final Category category;
  const AddCategoryEvent(this.category);
}

class UpdateCategoryEvent extends CategoryEvent {
  final Category category;
  const UpdateCategoryEvent(this.category);
}

class DeleteCategoryEvent extends CategoryEvent {
  final int id;
  const DeleteCategoryEvent(this.id);
}

class RestoreCategoryEvent extends CategoryEvent {
  final int id;
  const RestoreCategoryEvent(this.id);
}
