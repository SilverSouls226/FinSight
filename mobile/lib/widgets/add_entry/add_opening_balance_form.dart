import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import 'add_form_scaffold.dart';

class AddOpeningBalanceForm extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;

  const AddOpeningBalanceForm({super.key, required this.onBack, required this.onDone});

  @override
  ConsumerState<AddOpeningBalanceForm> createState() => _AddOpeningBalanceFormState();
}

class _AddOpeningBalanceFormState extends ConsumerState<AddOpeningBalanceForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(manualEntryServiceProvider).addOpeningBalance(
            amount: double.parse(_amountController.text.trim()),
          );
      ref.invalidate(financialSnapshotProvider);
      ref.invalidate(interventionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening balance set')),
      );
      widget.onDone();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save this right now. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AddFormScaffold(
        title: 'Set current balance',
        onBack: widget.onBack,
        saving: _saving,
        error: _error,
        onSave: _save,
        saveLabel: 'Set balance',
        children: [
          const Text(
            'New here? Set your current checking balance so the app isn\'t stuck at ₹0.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          AddAmountField(controller: _amountController),
        ],
      ),
    );
  }
}
