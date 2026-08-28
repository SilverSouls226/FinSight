import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import 'add_form_scaffold.dart';

const _recurrenceOptions = ['Weekly', 'Monthly', 'Quarterly', 'Yearly'];
const _currencyOptions = ['INR', 'USD', 'EUR'];

class AddIncomeForm extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;

  const AddIncomeForm({super.key, required this.onBack, required this.onDone});

  @override
  ConsumerState<AddIncomeForm> createState() => _AddIncomeFormState();
}

class _AddIncomeFormState extends ConsumerState<AddIncomeForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _sourceController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _recurring = false;
  String _recurrence = 'Monthly';
  String _currency = 'INR';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(manualEntryServiceProvider).addIncome(
            amount: double.parse(_amountController.text.trim()),
            vendor: _sourceController.text.trim(),
            date: _date,
            isRecurring: _recurring,
            currency: _currency,
          );
      ref.invalidate(financialSnapshotProvider);
      ref.invalidate(interventionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Income added')),
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
        title: 'Add income',
        onBack: widget.onBack,
        saving: _saving,
        error: _error,
        onSave: _save,
        children: [
          AddAmountField(controller: _amountController),
          AddTextField(
            controller: _sourceController,
            label: 'Source / From',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          AddDateField(value: _date, onChanged: (d) => setState(() => _date = d), label: 'Date received'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recurring', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
          ),
          if (_recurring)
            AddDropdownField<String>(
              value: _recurrence,
              label: 'Recurrence',
              options: _recurrenceOptions,
              labelOf: (v) => v,
              onChanged: (v) => setState(() => _recurrence = v),
            ),
          AddDropdownField<String>(
            value: _currency,
            label: 'Currency',
            options: _currencyOptions,
            labelOf: (v) => v,
            onChanged: (v) => setState(() => _currency = v),
          ),
        ],
      ),
    );
  }
}
