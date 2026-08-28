import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import 'add_form_scaffold.dart';

const _priorityOptions = ['High', 'Medium', 'Low'];

class AddGoalForm extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;

  const AddGoalForm({super.key, required this.onBack, required this.onDone});

  @override
  ConsumerState<AddGoalForm> createState() => _AddGoalFormState();
}

class _AddGoalFormState extends ConsumerState<AddGoalForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _savedController = TextEditingController(text: '0');
  String _priority = 'Medium';
  bool _hasDeadline = false;
  DateTime _deadline = DateTime.now().add(const Duration(days: 90));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(goalServiceProvider).addGoal(
            name: _nameController.text.trim(),
            targetAmount: double.parse(_targetController.text.trim()),
            currentAmount: double.tryParse(_savedController.text.trim()) ?? 0.0,
            priority: _priority.toLowerCase(),
            deadline: _hasDeadline ? _deadline : null,
          );
      ref.invalidate(financialSnapshotProvider);
      ref.invalidate(interventionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal added')),
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
        title: 'Add goal',
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
          AddAmountField(controller: _targetController, label: 'Target amount'),
          AddTextField(
            controller: _savedController,
            label: 'Already saved',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isEmpty) return null;
              if (double.tryParse(text) == null) return 'Enter a valid number';
              return null;
            },
          ),
          AddDropdownField<String>(
            value: _priority,
            label: 'Priority',
            options: _priorityOptions,
            labelOf: (v) => v,
            onChanged: (v) => setState(() => _priority = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set a target date', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            value: _hasDeadline,
            onChanged: (v) => setState(() => _hasDeadline = v),
          ),
          if (_hasDeadline)
            AddDateField(value: _deadline, onChanged: (d) => setState(() => _deadline = d), label: 'Target date'),
        ],
      ),
    );
  }
}
