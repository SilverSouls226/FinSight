import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'add_form_scaffold.dart';

const _categoryOptions = ['Food', 'Transport', 'Shopping', 'Health', 'Entertainment', 'Bills', 'Other'];
const _currencyOptions = ['INR', 'USD', 'EUR'];

class AddExpenseForm extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;

  const AddExpenseForm({super.key, required this.onBack, required this.onDone});

  @override
  ConsumerState<AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends ConsumerState<AddExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _paidToController = TextEditingController();
  String _category = 'Food';
  DateTime _date = DateTime.now();
  String _currency = 'INR';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _paidToController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(manualEntryServiceProvider).addExpense(
            amount: double.parse(_amountController.text.trim()),
            vendor: _paidToController.text.trim(),
            date: _date,
            currency: _currency,
          );
      ref.invalidate(financialSnapshotProvider);
      ref.invalidate(interventionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added')),
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
        title: 'Add expense',
        onBack: widget.onBack,
        saving: _saving,
        error: _error,
        onSave: _save,
        children: [
          AddAmountField(controller: _amountController),
          AddTextField(
            controller: _paidToController,
            label: 'Paid to / What',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          AddDropdownField<String>(
            value: _category,
            label: 'Category',
            options: _categoryOptions,
            labelOf: (v) => v,
            onChanged: (v) => setState(() => _category = v),
          ),
          AddDateField(value: _date, onChanged: (d) => setState(() => _date = d)),
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
