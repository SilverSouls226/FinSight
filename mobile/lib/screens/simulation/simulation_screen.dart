import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/simulation_result.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';
import '../../widgets/simulation_risk_bar.dart';

/// Screen 5: Simulation — "Can I afford this?"
class SimulationScreen extends ConsumerStatefulWidget {
  const SimulationScreen({super.key});

  @override
  ConsumerState<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends ConsumerState<SimulationScreen> {
  final _amountController = TextEditingController(text: '12000');
  SimulationResult? _result;
  bool _loading = false;
  Object? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _runSimulation() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid purchase amount.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await ref.read(financialSnapshotProvider.future);
      final service = ref.read(simulationServiceProvider);
      final result = await service.simulatePurchase(snapshot: snapshot, purchaseAmount: amount);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Can I afford this?')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Enter a purchase amount to see how it changes your shortfall risk over the next 30 days.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Purchase amount',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _runSimulation,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simulate'),
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) ErrorView(error: _error!, onRetry: _runSimulation),
          if (_result != null) _ResultCard(result: _result!),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SimulationResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For a ${formatCurrency(result.purchaseAmount)} purchase',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 18),
                SimulationRiskBar(label: 'WITHOUT PURCHASE', riskFraction: result.shortfallRiskWithoutPurchase),
                const SizedBox(height: 16),
                SimulationRiskBar(label: 'WITH PURCHASE', riskFraction: result.shortfallRiskWithPurchase),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Safe-to-spend after purchase',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    Text(
                      formatCurrency(result.safeToSpendAfterPurchase),
                      style: TextStyle(
                        color: result.safeToSpendAfterPurchase >= 0 ? AppColors.stable : AppColors.storm,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: (result.isAffordable ? AppColors.stable : AppColors.storm).withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  result.isAffordable ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                  color: result.isAffordable ? AppColors.stable : AppColors.storm,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.recommendation,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
