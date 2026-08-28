import 'mock_financial_state_service.dart';
import 'profile_sync_service.dart';

/// Offline implementation of [ProfileSyncService] -- applies the safety
/// buffer to the shared [MockFinancialStateService]'s overlay so
/// safe-to-spend reacts the same way it would live; nothing else about a
/// profile affects the snapshot contract.
class MockProfileSyncService implements ProfileSyncService {
  MockProfileSyncService(this._mockState);

  final MockFinancialStateService _mockState;

  @override
  Future<void> syncProfile({
    required String? name,
    required String riskTolerance,
    required double safetyBuffer,
    required List<String> priorities,
    String preferredCurrency = 'INR',
  }) async {
    _mockState.setSafetyBuffer(safetyBuffer);
  }
}
