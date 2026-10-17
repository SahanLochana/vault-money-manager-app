import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';
import 'package:money_management_app/presentation/blocs/category/category_event.dart';
import 'package:money_management_app/presentation/blocs/category/category_state.dart';
import 'package:money_management_app/services/notification_service.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository categoryRepository;

  CategoryBloc({required this.categoryRepository}) : super(const CategoryInitial()) {
    on<LoadCategoriesEvent>(_onLoadCategories);
    on<AddCategoryEvent>(_onAddCategory);
    on<UpdateCategoryEvent>(_onUpdateCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
    on<RestoreCategoryEvent>(_onRestoreCategory);
  }

  Future<void> _onLoadCategories(
    LoadCategoriesEvent event,
    Emitter<CategoryState> emit,
  ) async {
    emit(const CategoryLoading());
    try {
      final categories = await categoryRepository.getAllCategories();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onAddCategory(
    AddCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      await categoryRepository.addCategory(event.category);
      add(const LoadCategoriesEvent());
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onUpdateCategory(
    UpdateCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      await categoryRepository.updateCategory(event.category);
      add(const LoadCategoriesEvent());
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onDeleteCategory(
    DeleteCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      final deletedReminderIds = await categoryRepository.deleteCategory(event.id);
      for (final rId in deletedReminderIds) {
        await NotificationService.instance.cancelReminder(rId);
      }
      add(const LoadCategoriesEvent());
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onRestoreCategory(
    RestoreCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      await categoryRepository.restoreCategory(event.id);
      add(const LoadCategoriesEvent());
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<({int transactionCount, int reminderCount})> getDeleteImpact(int categoryId) async {
    final txCount = await categoryRepository.countTransactionsForCategory(categoryId);
    final remCount = await categoryRepository.countRemindersForCategory(categoryId);
    return (transactionCount: txCount, reminderCount: remCount);
  }
}
