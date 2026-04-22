import 'package:flutter/material.dart';

import '../models/completion_reward_summary.dart';
import '../services/xp_progression_service.dart';
import '../widgets/xp_title_style.dart';
import 'achievements_placeholder_screen.dart';

class ChecklistCompleteScreen extends StatefulWidget {
  final CompletionRewardSummary summary;
  final VoidCallback? onBackToHome;
  final VoidCallback? onViewRewards;
  final VoidCallback? onViewAchievements;

  const ChecklistCompleteScreen({
    super.key,
    required this.summary,
    this.onBackToHome,
    this.onViewRewards,
    this.onViewAchievements,
  });

  @override
  State<ChecklistCompleteScreen> createState() =>
      _ChecklistCompleteScreenState();
}

class _ChecklistCompleteScreenState extends State<ChecklistCompleteScreen>
    with SingleTickerProviderStateMixin {
  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  late final AnimationController _controller;
  late final Animation<double> _xpAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _xpAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _animatedXp {
    final CompletionRewardSummary summary = widget.summary;
    if (!summary.rewardGranted) {
      return summary.newXp;
    }

    final int delta = summary.newXp - summary.oldXp;
    return summary.oldXp + (delta * _xpAnimation.value).round();
  }

  String _formatDate(DateTime date) {
    final DateTime local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Future<void> _onBackToHome() async {
    widget.onBackToHome?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onViewRewards() async {
    widget.onViewRewards?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onViewAchievements() async {
    if (widget.onViewAchievements != null) {
      widget.onViewAchievements!.call();
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AchievementsPlaceholderScreen()),
    );
  }

  Widget _buildRewardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required int order,
  }) {
    final Animation<double> fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(0.2 + (order * 0.1), 0.9, curve: Curves.easeOut),
    );

    final Animation<Offset> slide =
        Tween<Offset>(begin: const Offset(0, 0.16), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              0.2 + (order * 0.1),
              0.95,
              curve: Curves.easeOutCubic,
            ),
          ),
        );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockSection() {
    final List<String> badges = widget.summary.unlockedBadges;
    final List<String> titles = widget.summary.unlockedTitles;
    final bool nothingUnlocked = badges.isEmpty && titles.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unlocks',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (nothingUnlocked)
            Text(
              'No new unlocks this time. Keep your streak alive to earn more badges and titles.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 14,
              ),
            )
          else ...[
            ...badges.map(
              (badge) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _unlockChip(
                  label: 'Badge unlocked: $badge',
                  color: _secondaryAccent,
                  icon: Icons.military_tech,
                ),
              ),
            ),
            ...titles.map(
              (title) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _unlockChip(
                  label: 'Title unlocked: $title',
                  color: _accentColor,
                  icon: Icons.workspace_premium,
                  labelStyle: XpTitleStyle.forTitle(
                    title,
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageCard() {
    final bool rewardGranted = widget.summary.rewardGranted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: rewardGranted
              ? _accentColor.withValues(alpha: 0.24)
              : _secondaryAccent.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rewardGranted ? Icons.auto_awesome : Icons.event_repeat,
            color: rewardGranted ? _accentColor : _secondaryAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.summary.message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    TextStyle? valueStyle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text(
            value,
            style:
                valueStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
          ),
        ],
      ),
    );
  }

  Widget _unlockChip({
    required String label,
    required Color color,
    required IconData icon,
    TextStyle? labelStyle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style:
                  labelStyle ??
                  const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CompletionRewardSummary summary = widget.summary;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final int currentXp = _animatedXp;
            final XpProgressSnapshot xpProgress = XpProgressionService.fromXp(
              currentXp,
            );
            final bool inLevelUpState =
                summary.rewardGranted &&
                summary.didLevelUp &&
                xpProgress.level > summary.oldLevel;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A243A), Color(0xFF0F1625)],
                    ),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mission Complete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nice work. You showed up today.',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Date: ${_formatDate(summary.completionDate)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if (summary.wasAlreadyClaimedToday) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _secondaryAccent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Daily rewards already claimed',
                            style: TextStyle(
                              color: _secondaryAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else if (inLevelUpState) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _secondaryAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Level Up! You reached Level ${summary.newLevel}',
                            style: const TextStyle(
                              color: _secondaryAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildMessageCard(),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_graph, color: _accentColor),
                          const SizedBox(width: 8),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Level ${xpProgress.level} • ',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: xpProgress.rankTitle,
                                  style: XpTitleStyle.forTitle(
                                    xpProgress.rankTitle,
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            xpProgress.xpRequiredForNextLevel > 0
                                ? '${xpProgress.currentXpWithinLevel} / ${xpProgress.xpRequiredForNextLevel} XP'
                                : 'MAX',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 12,
                          value: xpProgress.progressPercent,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.rewardGranted
                            ? '+${summary.xpEarned} XP gained • ${xpProgress.totalXp} total XP'
                            : '${xpProgress.totalXp} total XP',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (summary.rewardGranted) ...[
                  _buildRewardCard(
                    title: 'Coins earned',
                    value: '+${summary.coinsEarned}',
                    icon: Icons.monetization_on,
                    color: Colors.amber,
                    order: 0,
                  ),
                  const SizedBox(height: 10),
                  _buildRewardCard(
                    title: 'XP earned',
                    value: '+${summary.xpEarned}',
                    icon: Icons.bolt,
                    color: _accentColor,
                    order: 1,
                  ),
                  const SizedBox(height: 10),
                  _buildRewardCard(
                    title: 'Current streak',
                    value: '${summary.streak}',
                    icon: Icons.local_fire_department,
                    color: Colors.orangeAccent,
                    order: 2,
                  ),
                  const SizedBox(height: 10),
                  _buildRewardCard(
                    title: 'Perfect days',
                    value: '${summary.perfectDays}',
                    icon: Icons.stars,
                    color: Colors.lightBlueAccent,
                    order: 3,
                  ),
                ] else ...[
                  _buildProgressCard(
                    title: 'Current level',
                    value: '${xpProgress.level}',
                    icon: Icons.auto_graph,
                    color: _accentColor,
                  ),
                  const SizedBox(height: 10),
                  _buildProgressCard(
                    title: 'Rank title',
                    value: xpProgress.rankTitle,
                    icon: Icons.workspace_premium,
                    color: _secondaryAccent,
                    valueStyle: XpTitleStyle.forTitle(
                      xpProgress.rankTitle,
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildProgressCard(
                    title: 'Current streak',
                    value: '${summary.streak}',
                    icon: Icons.local_fire_department,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 10),
                  _buildProgressCard(
                    title: 'Perfect days',
                    value: '${summary.perfectDays}',
                    icon: Icons.stars,
                    color: Colors.lightBlueAccent,
                  ),
                ],
                const SizedBox(height: 14),
                _buildUnlockSection(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onBackToHome,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accentColor,
                          side: const BorderSide(color: _accentColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Back to My List'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _onViewRewards,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _secondaryAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('View Rewards'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _onViewAchievements,
                    icon: const Icon(Icons.emoji_events_outlined),
                    label: const Text('View Achievements'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
