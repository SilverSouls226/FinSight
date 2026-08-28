import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'add_form_scaffold.dart';

const _recurrenceOptions = ['Once', 'Weekly', 'Monthly', 'Quarterly', 'Yearly'];
const _categoryOptions = ['Fixed essential', 'Subscription', 'Discretionary'];

String _recurrenceKey(String label) => label.toLowerCase();
String _categoryKey(String label) => label.toLowerCase().replaceAll(' ', '_');

class AddObligationForm extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;

  const AddObligationForm({super.key, required this.onBack, required this.onDone});

  @override
  ConsumerState<AddObligationForm> createState() => _AddObligationFormState();
}

class _AddObligationFormState extends ConsumerState<AddObligationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _dueDate = DateTime.now();
  String _recurrence = 'Monthly';
  String _category = 'Fixed essential';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
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
      await ref.read(obligationServiceProvider).addObligation(
            name: _nameController.text.trim(),
            amount: double.parse(_amountController.text.trim()),
            dueDate: _dueDate,
            recurrence: _recurrenceKey(_recurrence),
            category: _categoryKey(_category),
          );
      ref.invalidate(financialSnapshotProvider);
      ref.invalidate(interventionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obligation added')),
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
        title: 'Add obligation',
        onBack: widget.onBack,
        saving: _saving,
        error: _error,
        onSave: _save,
        children: [
          AddTextField(
            controller: _nameController,
            label: 'Name',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          AddAmountField(controller: _amountController),
          AddDateField(value: _dueDate, onChanged: (d) => setState(() => _dueDate = d), label: 'Next due date'),
          AddDropdownField<String>(
            value: _recurrence,
            label: 'Recurrence',
            options: _recurrenceOptions,
            labelOf: (v) => v,
            onChanged: (v) => setState(() => _recurrence = v),
          ),
          AddDropdownField<String>(
            value: _category,
            label: 'Category',
            options: _categoryOptions,
            labelOf: (v) => v,
            onChanged: (v) => setState(() => _category = v),
          ),
        ],
      ),
    );
  }
}
