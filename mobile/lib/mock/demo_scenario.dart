import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/financial_state_snapshot.dart';
import '../models/intervention.dart';

/// One stage of the scripted hackathon demo flow (stable -> pressure ->
/// resolved), loaded from assets/mock/demo_scenario.json.
class DemoStage {
  final String stageId;
  final String label;
  final String triggerEvent;
  final FinancialStateSnapshot snapshot;
  final List<ContextualIntervention> interventions;

  const DemoStage({
    required this.stageId,
    required this.label,
    required this.triggerEvent,
    required this.snapshot,
    required this.interventions,
  });

  factory DemoStage.fromJson(Map<String, dynamic> json) {
    return DemoStage(
      stageId: json['stage_id'] as String,
      label: json['label'] as String,
      triggerEvent: json['trigger_event'] as String? ?? '',
      snapshot: FinancialStateSnapshot.fromJson(
        json['snapshot'] as Map<String, dynamic>,
      ),
      interventions: ((json['interventions'] as List?) ?? const [])
          .map((e) => ContextualIntervention.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Loads and caches the full scripted demo scenario from the bundled asset.
class DemoScenarioLoader {
  static const _assetPath = 'assets/mock/demo_scenario.json';

  List<DemoStage>? _cachedStages;

  Future<List<DemoStage>> loadStages() async {
    if (_cachedStages != null) return _cachedStages!;
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final stages = ((decoded['stages'] as List?) ?? const [])
        .map((e) => DemoStage.fromJson(e as Map<String, dynamic>))
        .toList();
    _cachedStages = stages;
    return stages;
  }
}
