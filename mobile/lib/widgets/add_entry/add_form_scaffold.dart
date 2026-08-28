import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Shared layout for every type-specific Add form: back button + title,
/// scrollable field area, and a footer Save button that shows a spinner
/// while saving and an inline error banner on failure (the sheet itself
/// never closes on error, so the user can fix input and retry).
class AddFormScaffold extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;
  final String? error;
  final String saveLabel;

  const AddFormScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.children,
    required this.onSave,
    required this.saving,
    this.error,
    this.saveLabel = 'Save',
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: saving ? null : onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + (bottomInset > 0 ? 8 : MediaQuery.of(context).padding.bottom)),
          child: Column(
            children: [
              if (error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.stormSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.storm.withValues(alpha: 0.4)),
                  ),
                  child: Text(error!, style: const TextStyle(color: AppColors.storm, fontSize: 12.5)),
                ),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Text(saveLabel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A required text field with the shared style + a not-empty validator.
class AddTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const AddTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary),
        validator: validator,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

/// Amount field: numeric keyboard, required + must be > 0.
class AddAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const AddAmountField({super.key, required this.controller, this.label = 'Amount'});

  @override
  Widget build(BuildContext context) {
    return AddTextField(
      controller: controller,
      label: label,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        final text = v?.trim() ?? '';
        if (text.isEmpty) return 'Required';
        final amount = double.tryParse(text);
        if (amount == null) return 'Enter a valid number';
        if (amount <= 0) return 'Must be greater than 0';
        return null;
      },
    );
  }
}

/// Date picker presented as a tappable field matching the Material text
/// field style, defaulting to today.
class AddDateField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;

  const AddDateField({super.key, required this.value, required this.onChanged, this.label = 'Date'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(
            '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class AddDropdownField<T> extends StatelessWidget {
  final T value;
  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const AddDropdownField({
    super.key,
    required this.value,
    required this.label,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        dropdownColor: AppColors.surfaceRaised,
        style: const TextStyle(color: AppColors.textPrimary),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(labelOf(o)))).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
