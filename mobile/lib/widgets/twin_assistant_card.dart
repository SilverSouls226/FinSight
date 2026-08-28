import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/financial_state_snapshot.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/twin_projection.dart';

/// A chat panel powered by Sameer's real Groq-backed `/api/chat/{user_id}`
/// endpoint -- answers any freeform question grounded in the same
/// [FinancialStateSnapshot] rendered above it, not just a fixed script.
/// Falls back to a small local answer set only if the network call fails,
/// so the assistant never goes silent.
class TwinAssistantCard extends ConsumerStatefulWidget {
  final FinancialStateSnapshot snapshot;

  const TwinAssistantCard({super.key, required this.snapshot});

  @override
  ConsumerState<TwinAssistantCard> createState() => _TwinAssistantCardState();
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  final bool isFallback;
  const _ChatMessage(this.text, this.fromUser, {this.isFallback = false});
}

class _TwinAssistantCardState extends ConsumerState<TwinAssistantCard> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  late final AnimationController _pulseController;
  bool _isThinking = false;
  bool _lastAnswerWasFallback = false;

  static const _suggestions = [
    'Am I safe this month?',
    'What should I cut back on?',
    'How are my goals?',
    'What\'s my runway?',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _messages.add(const _ChatMessage(
      "Hi, I'm your Twin Assistant, backed by a real AI model. Ask me "
      "anything about your finances — not just the suggestions below.",
      false,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
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

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(_ChatMessage(text, true));
      _isThinking = true;
    });
    _controller.clear();
    _scrollToBottom();

    String answer;
    bool wasFallback = false;
    try {
      final chatService = ref.read(chatServiceProvider);
      answer = await chatService.ask(text, widget.snapshot);
      if (answer.trim().isEmpty) {
        answer = _localAnswer(text);
        wasFallback = true;
      }
    } catch (_) {
      answer = _localAnswer(text);
      wasFallback = true;
    }

    if (!mounted) return;
    setState(() {
      _isThinking = false;
      _lastAnswerWasFallback = wasFallback;
      _messages.add(_ChatMessage(answer, false, isFallback: wasFallback));
    });
    _scrollToBottom();
  }

  /// Local, rule-based fallback -- only used if the real API is unreachable.
  String _localAnswer(String question) {
    final q = question.toLowerCase();
    final snapshot = widget.snapshot;

    if (q.contains('safe') || q.contains('afford') || q.contains('risk')) {
      final risk = snapshot.shortfallProbability30d;
      final riskText =
          risk != null ? ' Your modeled shortfall risk is ${(risk * 100).toStringAsFixed(0)}%.' : '';
      return 'You have ${formatCurrency(snapshot.safeToSpend)} safe to spend right now.$riskText';
    }

    if (q.contains('due') || q.contains('obligation') || q.contains('bill') || q.contains('next')) {
      if (snapshot.upcomingObligations.isEmpty) {
        return 'You have no upcoming obligations tracked right now.';
      }
      final sorted = [...snapshot.upcomingObligations]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final next = sorted.first;
      final days = next.dueDate.difference(snapshot.lastUpdated).inDays;
      return '${next.name} — ${formatCurrency(next.amount)}, due in $days day${days == 1 ? '' : 's'}.';
    }

    if (q.contains('goal')) {
      if (snapshot.activeGoals.isEmpty) return 'You don\'t have any active goals set up yet.';
      return snapshot.activeGoals
          .map((g) => '${g.name}: ${(g.progress * 100).toStringAsFixed(0)}%')
          .join(', ');
    }

    if (q.contains('runway')) {
      final runway = TwinProjection.runwayDays(snapshot);
      return runway == null
          ? 'Your projected balance stays positive for the full 30-day horizon.'
          : 'At current pace, your balance is projected to go negative in $runway day${runway == 1 ? '' : 's'}.';
    }

    return 'I couldn\'t reach the AI model just now, but I can still tell you about your '
        'safe-to-spend, obligations, goals, or runway from what\'s on screen.';
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
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final glow = 0.5 + (_pulseController.value * 0.5);
                    return Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.9),
                            AppColors.accent.withValues(alpha: 0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: _isThinking ? glow * 0.55 : 0.0),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                    );
                  },
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
                _StatusBadge(thinking: _isThinking, lastWasFallback: _lastAnswerWasFallback),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: _messages.length + (_isThinking ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return const _TypingBubble();
                  return _MessageBubble(message: _messages[i]);
                },
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
                        onPressed: _isThinking ? null : () => _send(s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isThinking,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ask anything about your finances…',
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
                  onPressed: _isThinking ? null : () => _send(_controller.text),
                  icon: _isThinking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
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

class _StatusBadge extends StatelessWidget {
  final bool thinking;
  final bool lastWasFallback;

  const _StatusBadge({required this.thinking, required this.lastWasFallback});

  @override
  Widget build(BuildContext context) {
    if (thinking) {
      return const Text('thinking…', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
    }
    final color = lastWasFallback ? AppColors.pressure : AppColors.stable;
    final label = lastWasFallback ? 'offline mode' : 'AI-powered';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_controller.value - i * 0.2) % 1.0).clamp(0.0, 1.0);
            final scale = 0.5 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: 0.4 + scale * 0.6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
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
                  border: Border.all(
                    color: message.isFallback ? AppColors.pressure.withValues(alpha: 0.4) : AppColors.border,
                  ),
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
