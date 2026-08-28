import 'package:flutter/material.dart';

import '../models/financial_state_snapshot.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/twin_projection.dart';

/// A lightweight, on-device "Twin Assistant" chat panel.
///
/// This is intentionally NOT a call to any LLM/backend — none of the three
/// real services expose a freeform-chat endpoint. It answers a handful of
/// common questions by pattern-matching against the same
/// [FinancialStateSnapshot] already rendered on this screen, so answers are
/// always consistent with what the user sees above.
class TwinAssistantCard extends StatefulWidget {
  final FinancialStateSnapshot snapshot;

  const TwinAssistantCard({super.key, required this.snapshot});

  @override
  State<TwinAssistantCard> createState() => _TwinAssistantCardState();
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  const _ChatMessage(this.text, this.fromUser);
}

class _TwinAssistantCardState extends State<TwinAssistantCard> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  static const _suggestions = [
    'Am I safe this month?',
    'What\'s due next?',
    'How are my goals?',
    'What\'s my runway?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      "Hi, I'm your Twin Assistant. Ask me about your balance, obligations, "
      "goals, or runway — I read straight from the twin above.",
      false,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text, true));
      _messages.add(_ChatMessage(_answer(text), false));
    });
    _controller.clear();
    _scrollToBottom();
  }

  String _answer(String question) {
    final q = question.toLowerCase();
    final snapshot = widget.snapshot;

    if (q.contains('safe') || q.contains('afford') || q.contains('risk')) {
      final risk = snapshot.shortfallProbability30d;
      final riskText = risk != null
          ? ' Your modeled shortfall risk is ${(risk * 100).toStringAsFixed(0)}%.'
          : '';
      return 'You have ${formatCurrency(snapshot.safeToSpend)} safe to spend right now.$riskText';
    }

    if (q.contains('due') || q.contains('obligation') || q.contains('bill') || q.contains('next')) {
      if (snapshot.upcomingObligations.isEmpty) {
        return 'You have no upcoming obligations tracked right now.';
      }
      final sorted = [...snapshot.upcomingObligations]
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final next = sorted.first;
      final days = next.dueDate.difference(snapshot.lastUpdated).inDays;
      return '${next.name} — ${formatCurrency(next.amount)}, due in $days day${days == 1 ? '' : 's'}. '
          'Total upcoming obligations: ${formatCurrency(snapshot.totalUpcomingObligations)}.';
    }

    if (q.contains('goal')) {
      if (snapshot.activeGoals.isEmpty) {
        return 'You don\'t have any active goals set up yet.';
      }
      final lines = snapshot.activeGoals.map((g) =>
          '${g.name}: ${(g.progress * 100).toStringAsFixed(0)}% (${formatCurrency(g.currentAmount)} of ${formatCurrency(g.targetAmount)})');
      return lines.join('\n');
    }

    if (q.contains('runway') || q.contains('last') || q.contains('negative')) {
      final runway = TwinProjection.runwayDays(snapshot);
      if (runway == null) {
        return 'Your projected balance stays positive for the full 30-day horizon. No runway concern right now.';
      }
      return 'At current pace, your balance is projected to go negative in $runway day${runway == 1 ? '' : 's'}.';
    }

    if (q.contains('income')) {
      final income = snapshot.projectedIncome30Days;
      return 'Projected income over the next 30 days: ${formatCurrency(income.estimatedAmount)} '
          '(± ${formatCurrency(income.variance)}).';
    }

    if (q.contains('balance') || q.contains('checking') || q.contains('savings')) {
      return 'Checking: ${formatCurrency(snapshot.currentBalances.checking)} · '
          'Savings: ${formatCurrency(snapshot.currentBalances.savings)} · '
          'Total: ${formatCurrency(snapshot.totalBalance)}.';
    }

    return "I can tell you about your safe-to-spend amount, upcoming obligations, "
        "goals, runway, income, or balances — try asking about one of those.";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology_alt_rounded, color: AppColors.accent, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'TWIN ASSISTANT',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: AppColors.stable, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text('live twin data', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: _messages.length,
                itemBuilder: (context, i) => _MessageBubble(message: _messages[i]),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions
                  .map((s) => ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.surfaceRaised,
                        side: const BorderSide(color: AppColors.border),
                        onPressed: () => _send(s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ask about your finances…',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceRaised,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _send(_controller.text),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 6), child: child),
        ),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.accentSoft : AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, height: 1.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
