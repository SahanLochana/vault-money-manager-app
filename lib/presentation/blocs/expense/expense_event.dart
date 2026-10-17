import 'package:money_management_app/domain/models/ledger_transaction.dart';

abstract class ExpenseEvent {
  const ExpenseEvent();
}

class LoadExpenses extends ExpenseEvent {
  const LoadExpenses();
}

class LoadTodayExpenses extends ExpenseEvent {
  const LoadTodayExpenses();
}

class LoadMoreExpenses extends ExpenseEvent {
  const LoadMoreExpenses();
}

class AddExpenseEvent extends ExpenseEvent {
  final LedgerTransaction expense;
  const AddExpenseEvent(this.expense);
}

class UpdateExpenseEvent extends ExpenseEvent {
  final LedgerTransaction expense;
  const UpdateExpenseEvent(this.expense);
}

class DeleteExpenseEvent extends ExpenseEvent {
  final int id;
  const DeleteExpenseEvent(this.id);
}

class RestoreExpenseEvent extends ExpenseEvent {
  final int id;
  const RestoreExpenseEvent(this.id);
}

class ClearAllExpensesEvent extends ExpenseEvent {
  const ClearAllExpensesEvent();
}
