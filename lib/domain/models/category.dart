import 'package:money_management_app/data/database/tables.dart';

class CategoryKind {
  static const String expense = 'expense';
  static const String income = 'income';
}

class Category {
  final int? id;
  final String kind; // 'expense' or 'income'
  final String name;
  final String emoji;
  final int defaultAmountCents;
  final int sortOrder;
  final String? deletedAt;
  final String createdAt;

  const Category({
    this.id,
    this.kind = CategoryKind.expense,
    required this.name,
    required this.emoji,
    this.defaultAmountCents = 0,
    this.sortOrder = 0,
    this.deletedAt,
    this.createdAt = '',
  }) : assert(defaultAmountCents >= 0, 'defaultAmountCents must be >= 0');

  double get defaultAmount => defaultAmountCents / 100.0;
  bool get isDeleted => deletedAt != null;
  bool get isExpense => kind == CategoryKind.expense;
  bool get isIncome => kind == CategoryKind.income;

  Category copyWith({
    int? id,
    String? kind,
    String? name,
    String? emoji,
    int? defaultAmountCents,
    int? sortOrder,
    String? deletedAt,
    String? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      defaultAmountCents: defaultAmountCents ?? this.defaultAmountCents,
      sortOrder: sortOrder ?? this.sortOrder,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) AppTables.colCatId: id,
      AppTables.colCatKind: kind,
      AppTables.colCatName: name,
      AppTables.colCatEmoji: emoji,
      AppTables.colCatDefaultAmountCents: defaultAmountCents,
      AppTables.colCatSortOrder: sortOrder,
      AppTables.colCatDeletedAt: deletedAt,
      AppTables.colCatCreatedAt: createdAt.isNotEmpty ? createdAt : DateTime.now().toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map[AppTables.colCatId] as int?,
      kind: (map[AppTables.colCatKind] as String?) ?? 'expense',
      name: map[AppTables.colCatName] as String,
      emoji: map[AppTables.colCatEmoji] as String,
      defaultAmountCents: (map[AppTables.colCatDefaultAmountCents] as int?) ?? 0,
      sortOrder: (map[AppTables.colCatSortOrder] as int?) ?? 0,
      deletedAt: map[AppTables.colCatDeletedAt] as String?,
      createdAt: (map[AppTables.colCatCreatedAt] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          kind == other.kind;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ kind.hashCode;
}
