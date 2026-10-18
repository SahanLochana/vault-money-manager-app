import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/utils/currency_formatter.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/app_dialog_shell.dart';
import 'package:money_management_app/presentation/widgets/app_text_field.dart';
import 'package:money_management_app/presentation/widgets/emoji_picker_grid.dart';
import 'package:money_management_app/presentation/widgets/labeled_field.dart';

class WalletFormDialog extends StatefulWidget {
  final Wallet? walletToEdit;
  final List<Wallet> existingWallets;

  const WalletFormDialog({
    super.key,
    this.walletToEdit,
    required this.existingWallets,
  });

  static Future<Wallet?> show(
    BuildContext context, {
    Wallet? walletToEdit,
    required List<Wallet> existingWallets,
  }) {
    return showDialog<Wallet>(
      context: context,
      builder: (context) => WalletFormDialog(
        walletToEdit: walletToEdit,
        existingWallets: existingWallets,
      ),
    );
  }

  @override
  State<WalletFormDialog> createState() => _WalletFormDialogState();
}

class _WalletFormDialogState extends State<WalletFormDialog> {
  static const List<String> _walletEmojis = [
    '💵', '💳', '🏦', '💰', '👛', '🪙', '💼', '🏷️', '🏧', '📈', '💎', '🧾',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _selectedEmoji;

  String? _nameError;
  String? _balanceError;
  bool _isSubmitting = false;

  bool get isEditMode => widget.walletToEdit != null;

  @override
  void initState() {
    super.initState();
    final wallet = widget.walletToEdit;
    _nameController = TextEditingController(text: wallet?.name ?? '');
    _balanceController = TextEditingController(
      text: wallet != null && wallet.openingBalance > 0
          ? wallet.openingBalance.toStringAsFixed(2)
          : '',
    );
    _selectedEmoji = wallet?.emoji ?? _walletEmojis.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    if (_isSubmitting) return;

    final rawName = _nameController.text.trim();
    final rawBalance = _balanceController.text.trim();

    String? nameErr;
    String? balanceErr;

    // 1. Name validation
    if (rawName.isEmpty) {
      nameErr = "Wallet name is required.";
    } else if (rawName.length > 24) {
      nameErr = "Name cannot exceed 24 characters.";
    } else {
      final nameLower = rawName.toLowerCase();
      final isDuplicate = widget.existingWallets.any((w) {
        if (isEditMode && w.id == widget.walletToEdit!.id) {
          return false;
        }
        return w.name.trim().toLowerCase() == nameLower;
      });
      if (isDuplicate) {
        nameErr = "A wallet with this name already exists.";
      }
    }

    // 2. Opening balance validation
    int? openingCents;
    if (rawBalance.isNotEmpty) {
      openingCents = CurrencyFormatter.tryParseToCents(rawBalance);
      if (openingCents == null) {
        balanceErr = "Enter a valid amount (up to Rs 999,999,999.99).";
      }
    } else {
      openingCents = 0;
    }

    if (nameErr != null || balanceErr != null) {
      setState(() {
        _nameError = nameErr;
        _balanceError = balanceErr;
      });
      return;
    }

    setState(() {
      _nameError = null;
      _balanceError = null;
      _isSubmitting = true;
    });

    final wallet = isEditMode
        ? widget.walletToEdit!.copyWith(
            name: rawName,
            emoji: _selectedEmoji,
            openingBalanceCents: openingCents!,
          )
        : Wallet(
            id: 0,
            name: rawName,
            emoji: _selectedEmoji,
            openingBalanceCents: openingCents!,
            createdAt: DateTime.now().toIso8601String(),
          );

    Navigator.of(context).pop(wallet);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AppDialogShell(
          title: isEditMode ? "Edit Wallet" : "Add New Wallet",
          confirmLabel: isEditMode ? "Save" : "Create",
          confirmColor: AppColors.primary,
          onConfirm: _isSubmitting ? null : _validateAndSubmit,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: "Choose Emoji",
                  child: EmojiPickerGrid(
                    emojis: _walletEmojis,
                    selectedEmoji: _selectedEmoji,
                    onSelected: (e) => setState(() => _selectedEmoji = e),
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Wallet Name",
                  child: AppTextField(
                    controller: _nameController,
                    hintText: "e.g. Cash, Bank Account, Savings",
                    autofocus: !isEditMode,
                    maxLength: 24,
                    textInputAction: TextInputAction.next,
                    errorText: _nameError,
                    onChanged: (val) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: isEditMode ? "Opening Balance" : "Opening Balance (Optional)",
                  child: AppTextField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    hintText: "0.00",
                    prefixText: "Rs ",
                    textInputAction: TextInputAction.done,
                    errorText: _balanceError,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: (val) {
                      if (_balanceError != null) {
                        setState(() => _balanceError = null);
                      }
                    },
                    onSubmitted: (_) => _validateAndSubmit(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
