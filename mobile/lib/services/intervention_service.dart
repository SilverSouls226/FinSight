import '../models/intervention.dart';

/// Abstraction over "where Contextual Interventions come from".
///
/// The UI depends only on this interface. Swap [MockInterventionService]
/// for [ApiInterventionService] at the provider wiring layer with zero
/// screen/widget changes.
abstract class InterventionService {
  Future<List<ContextualIntervention>> fetchInterventions(String userId);
}
