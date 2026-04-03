import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class RewardsScreen extends StatelessWidget {
  final int coins;
  final Map<String, dynamic> userData;
  final Future<void> Function(String) onRedeemReward;
  final Future<void> Function()? onUseSkipToday;

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _accentColor = Color(0xFFFFC857);
  static const Color _mintColor = Color(0xFF55E6C1);

  const RewardsScreen({
    super.key,
    required this.coins,
    required this.userData,
    required this.onRedeemReward,
    this.onUseSkipToday,
  });

  List<_RewardItem> _rewards() {
    return const <_RewardItem>[
      _RewardItem(
        id: FirestoreService.rewardStreakFreeze,
        title: 'Streak Freeze',
        subtitle: 'Prevents one missed day from resetting your streak.',
        cost: 40,
        icon: Icons.ac_unit_rounded,
        inventoryField: 'streakFreezeCount',
      ),
      _RewardItem(
        id: FirestoreService.rewardMissedDayPass,
        title: 'Missed Day Pass',
        subtitle: 'Restores a missed streak one time after a miss.',
        cost: 60,
        icon: Icons.restore_rounded,
        inventoryField: 'missedDayPassCount',
      ),
      _RewardItem(
        id: FirestoreService.rewardDoubleXpTomorrow,
        title: 'Double XP Tomorrow',
        subtitle: 'Your next eligible full checklist completion grants 2x XP.',
        cost: 50,
        icon: Icons.auto_graph_rounded,
        inventoryField: 'doubleXpTomorrow',
      ),
      _RewardItem(
        id: FirestoreService.rewardAutoCompleteTask,
        title: 'Auto Complete Task',
        subtitle: 'Grants one token that can auto-complete one task.',
        cost: 30,
        icon: Icons.task_alt_rounded,
        inventoryField: 'autoCompleteTaskTokens',
      ),
      _RewardItem(
        id: FirestoreService.rewardThreeDayShield,
        title: '3-Day Streak Shield',
        subtitle: 'Protects streak resets for your next 3 missed days.',
        cost: 100,
        icon: Icons.security_rounded,
        inventoryField: 'streakShieldDays',
      ),
      _RewardItem(
        id: FirestoreService.rewardDoubleCoinsTomorrow,
        title: 'Double Coins Tomorrow',
        subtitle:
            'Your next eligible full checklist completion grants 2x coins.',
        cost: 50,
        icon: Icons.paid_rounded,
        inventoryField: 'doubleCoinsTomorrow',
      ),
      _RewardItem(
        id: FirestoreService.rewardPlusOneStreakDay,
        title: '+1 Streak Day',
        subtitle: 'Instantly adds 1 day to your current streak.',
        cost: 70,
        icon: Icons.local_fire_department_rounded,
      ),
      _RewardItem(
        id: FirestoreService.rewardSkipTodaySafe,
        title: 'Skip Today (Streak Safe)',
        subtitle: 'Adds a token to safely skip a day without streak loss.',
        cost: 80,
        icon: Icons.event_busy_rounded,
        inventoryField: 'skipTodayTokens',
      ),
      _RewardItem(
        id: FirestoreService.rewardMysteryBox,
        title: 'Mystery Box',
        subtitle: 'Random reward: XP, coins, or utility boosts.',
        cost: 50,
        icon: Icons.casino_rounded,
      ),
    ];
  }

  String? _inventoryLabel(_RewardItem reward) {
    if (reward.inventoryField == null) {
      return null;
    }

    if (reward.inventoryField == 'doubleXpTomorrow') {
      return userData['doubleXpTomorrow'] == true
          ? 'Owned: Active'
          : 'Owned: Inactive';
    }

    if (reward.inventoryField == 'doubleCoinsTomorrow') {
      return userData['doubleCoinsTomorrow'] == true
          ? 'Owned: Active'
          : 'Owned: Inactive';
    }

    final int count = (userData[reward.inventoryField!] as int?) ?? 0;
    return 'Owned: $count';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2335), Color(0xFF101522)],
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rewards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Stay consistent and unlock bigger rewards.',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentColor.withValues(alpha: 0.24)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: _accentColor,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your Coins',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$coins',
                    style: const TextStyle(
                      color: _accentColor,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (((userData['skipTodayTokens'] as int?) ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onUseSkipToday,
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(
                      'Use Skip Today Token (${(userData['skipTodayTokens'] as int?) ?? 0} available)',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _mintColor,
                      side: BorderSide(
                        color: _mintColor.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            for (final _RewardItem reward in _rewards())
              _rewardTile(context: context, reward: reward),
          ],
        ),
      ),
    );
  }

  Widget _rewardTile({
    required BuildContext context,
    required _RewardItem reward,
  }) {
    final bool canRedeem = coins >= reward.cost;
    final String? inventoryLabel = _inventoryLabel(reward);

    return Card(
      color: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (canRedeem ? _mintColor : Colors.white24).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (canRedeem ? _mintColor : _accentColor).withValues(
                    alpha: 0.14,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  reward.icon,
                  size: 24,
                  color: canRedeem ? _mintColor : _accentColor,
                ),
              ),
              title: Text(
                reward.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                reward.subtitle,
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: Text(
                '${reward.cost}',
                style: TextStyle(
                  color: canRedeem ? _mintColor : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (inventoryLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    inventoryLabel,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canRedeem
                    ? () {
                        onRedeemReward(reward.id);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canRedeem
                      ? _accentColor
                      : Colors.grey.shade700,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(canRedeem ? 'Redeem' : 'Locked'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardItem {
  final String id;
  final String title;
  final String subtitle;
  final int cost;
  final IconData icon;
  final String? inventoryField;

  const _RewardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.icon,
    this.inventoryField,
  });
}
