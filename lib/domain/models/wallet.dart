import 'package:money_management_app/data/database/tables.dart';

class Wallet {
  final int id;
  final String name;
  final String emoji;
  final int openingBalanceCents;
  final int sortOrder;
  final bool isArchived;
  final String createdAt;
  final int? balanceCents;
  final int? totalFundsCents;
  final int? totalSpentCents;

  const Wallet({
    required this.id,
    required this.name,
    required this.emoji,
    this.openingBalanceCents = 0,
    this.sortOrder = 0,
    this.isArchived = false,
    String? createdAt,
    this.balanceCents,
    this.totalFundsCents,
    this.totalSpentCents,
  }) : createdAt = createdAt ?? '';

  double get openingBalance => openingBalanceCents / 100.0;
  double get balance => (balanceCents ?? openingBalanceCents) / 100.0;
  double get totalFunds => (totalFundsCents ?? 0) / 100.0;
  double get totalSpent => (totalSpentCents ?? 0) / 100.0;

  Wallet copyWith({
    int? id,
    String? name,
    String? emoji,
    int? openingBalanceCents,
    int? sortOrder,
    bool? isArchived,
    String? createdAt,
    int? balanceCents,
    int? totalFundsCents,
    int? totalSpentCents,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      openingBalanceCents: openingBalanceCents ?? this.openingBalanceCents,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      balanceCents: balanceCents ?? this.balanceCents,
      totalFundsCents: totalFundsCents ?? this.totalFundsCents,
      totalSpentCents: totalSpentCents ?? this.totalSpentCents,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppTables.colWalletId: id,
      AppTables.colWalletName: name,
      AppTables.colWalletEmoji: emoji,
      AppTables.colWalletOpeningBalanceCents: openingBalanceCents,
      AppTables.colWalletSortOrder: sortOrder,
      AppTables.colWalletIsArchived: isArchived ? 1 : 0,
      AppTables.colWalletCreatedAt: createdAt.isNotEmpty ? createdAt : DateTime.now().toIso8601String(),
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map[AppTables.colWalletId] as int,
      name: map[AppTables.colWalletName] as String,
      emoji: map[AppTables.colWalletEmoji] as String,
      openingBalanceCents: (map[AppTables.colWalletOpeningBalanceCents] as int?) ?? 0,
      sortOrder: (map[AppTables.colWalletSortOrder] as int?) ?? 0,
      isArchived: (map[AppTables.colWalletIsArchived] as int? ?? 0) == 1,
      createdAt: (map[AppTables.colWalletCreatedAt] as String?) ?? '',
      balanceCents: map['balance_cents'] as int?,
      totalFundsCents: map['total_funds_cents'] as int?,
      totalSpentCents: map['total_spent_cents'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wallet &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
