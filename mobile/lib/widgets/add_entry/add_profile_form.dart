import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import 'add_form_scaffold.dart';

const _currencyOptions = ['INR', 'USD', 'EUR'];

/// "Set up profile & preferences" -- also doubles as the edit form for an
/// existing profile (pre-fills from [userProfileProvider] if one exists).
/// Saves locally (same as onboarding, so the app still works fully
/// offline) and best-effort syncs to the backend so `safety_buffer`
/// actually affects the real safe-to-spend calculation; a sync failure
/// never blocks or reverts the local save.
class AddProfileForm extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;

  const AddProfileForm({super.key, required this.onBack, required this.onDone});

  @override
  ConsumerState<AddProfileForm> createState() => _AddProfileFormState();
}

class _AddProfileFormState extends ConsumerState<AddProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bufferController;
  late RiskTolerance _riskTolerance;
  late Set<FinancialPriority> _priorities;
  late String _currency;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(userProfileProvider);
    _nameController = TextEditingController(text: existing?.name ?? '');
    _bufferController = TextEditingController(text: (existing?.safetyBuffer ?? 100.0).toStringAsFixed(0));
    _riskTolerance = existing?.riskTolerance ?? RiskTolerance.moderate;
    _priorities = {...(existing?.priorities ?? const [])};
    _currency = existing?.preferredCurrency ?? 'INR';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bufferController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final buffer = double.tryParse(_bufferController.text.trim()) ?? 100.0;
    final existing = ref.read(userProfileProvider);
    final profile = (existing ?? UserProfile.empty).copyWith(
      name: _nameController.text.trim(),
      riskTolerance: _riskTolerance,
      priorities: _priorities.toList(),
      safetyBuffer: buffer,
      preferredCurrency: _currency,
    );

    // Local save is the source of truth for the onboarding gate -- it
    // must succeed even if the backend is unreachable.
    ref.read(userProfileProvider.notifier).complete(profile);

    try {
      await ref.read(profileSyncServiceProvider).syncProfile(
            name: profile.name,
            riskTolerance: profile.riskTolerance.name,
            safetyBuffer: profile.safetyBuffer,
            priorities: profile.priorities.map((p) => p.name).toList(),
            preferredCurrency: profile.preferredCurrency,
          );
    } catch (_) {
      // Best-effort only -- the local save above already succeeded, so
      // this doesn't block the user; just let them know it's not synced.
    }

    ref.invalidate(financialSnapshotProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
    setState(() => _saving = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AddFormScaffold(
        title: 'Profile & preferences',
        onBack: widget.onBack,
        saving: _saving,
        error: _error,
        onSave: _save,
        children: [
          AddTextField(controller: _nameController, label: 'Name'),
          AddDropdownField<RiskTolerance>(
            value: _riskTolerance,
            label: 'Risk tolerance',
            options: RiskTolerance.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _riskTolerance = v),
          ),
          AddTextField(
            controller: _bufferController,
            label: 'Safety buffer (minimum cash reserve)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isEmpty) return null;
              if (double.tryParse(text) == null) return 'Enter a valid number';
              return null;
            },
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Priorities', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FinancialPriority.values.map((p) {
              final selected = _priorities.contains(p);
              return FilterChip(
                label: Text(p.label),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _priorities.add(p);
                  } else {
                    _priorities.remove(p);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          AddDropdownField<String>(
            value: _currency,
            label: 'Preferred currency',
            options: _currencyOptions,
            labelOf: (v) => v,
            onChanged: (v) => setState(() => _currency = v),
          ),
        ],
      ),
    );
  }
}
