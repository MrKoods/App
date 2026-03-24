import 'package:flutter/material.dart';

class RewardsScreen extends StatelessWidget {
  final int coins;
  final Function(int, String) onRedeemReward;

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _accentColor = Color(0xFFFFC857);
  static const Color _mintColor = Color(0xFF55E6C1);

  const RewardsScreen({
    super.key,
    required this.coins,
    required this.onRedeemReward,
  });

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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
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
            const SizedBox(height: 24),
            _rewardTile(
              context: context,
              title: 'Small Reward',
              subtitle: 'Redeem at 25 coins',
              icon: Icons.card_giftcard,
              cost: 25,
            ),
            _rewardTile(
              context: context,
              title: 'Medium Reward',
              subtitle: 'Redeem at 50 coins',
              icon: Icons.stars,
              cost: 50,
            ),
            _rewardTile(
              context: context,
              title: 'Cash Reward',
              subtitle: 'Redeem at 100 coins',
              icon: Icons.attach_money,
              cost: 100,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required int cost,
    bool compact = false,
  }) {
    bool canRedeem = coins >= cost;

    return Card(
      color: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (canRedeem ? _mintColor : Colors.white24).withValues(alpha: 0.3),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(compact ? 6 : 8),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 16,
                vertical: compact ? 2 : 0,
              ),
              minVerticalPadding: compact ? 0 : null,
              leading: Container(
                width: compact ? 36 : 42,
                height: compact ? 36 : 42,
                decoration: BoxDecoration(
                  color: (canRedeem ? _mintColor : _accentColor).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: compact ? 20 : 24,
                  color: canRedeem ? _mintColor : _accentColor,
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: Text(
                '$cost',
                style: TextStyle(
                  color: canRedeem ? _mintColor : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 14 : 16,
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canRedeem
                    ? () {
                        onRedeemReward(cost, title);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canRedeem ? _accentColor : Colors.grey.shade700,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
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