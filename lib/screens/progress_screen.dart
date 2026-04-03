import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/xp_progression_service.dart';
import '../widgets/xp_title_style.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, this.initialUserData});

  final Map<String, dynamic>? initialUserData;

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _surfaceAltColor = Color(0xFF101522);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  int _readInt(dynamic value, {required int fallback}) {
    final int parsed = (value as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  Widget _buildHeader({
    required String greeting,
    required int level,
    required String rankTitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF162033), Color(0xFF0F1420)],
        ),
        border: Border.all(color: _accentColor.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your Progress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Level $level',
                  style: const TextStyle(
                    color: _accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rankTitle,
                  style: XpTitleStyle.forTitle(
                    rankTitle,
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildXpCard({required XpProgressSnapshot xpSnapshot}) {
    final bool isMaxLevel = xpSnapshot.xpRequiredForNextLevel <= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_graph, color: _accentColor, size: 22),
              SizedBox(width: 10),
              Text(
                'XP Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isMaxLevel
                ? 'Max level reached'
                : '${xpSnapshot.currentXpWithinLevel} / ${xpSnapshot.xpRequiredForNextLevel} XP',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: xpSnapshot.progressPercent,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(_accentColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${xpSnapshot.totalXp} total XP',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final String? email = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(title: const Text('Progress')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: firestoreService.watchUserData(),
        initialData: initialUserData,
        builder: (context, snapshot) {
          final Map<String, dynamic> userData =
              snapshot.data ?? <String, dynamic>{};

          final int coins = _readInt(userData['coins'], fallback: 0);
          final int currentStreak = _readInt(
            userData['currentStreak'],
            fallback: 0,
          );
          final int longestStreak = _readInt(
            userData['longestStreak'],
            fallback: 0,
          );
          final int perfectDays = _readInt(
            userData['perfectDays'],
            fallback: 0,
          );
          final int xp = _readInt(userData['xp'], fallback: 0);

          final XpProgressSnapshot xpSnapshot = XpProgressionService.fromXp(xp);
          final String greeting = email == null || email.isEmpty
              ? 'Keep it going.'
              : 'Hey, $email';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildHeader(
                greeting: greeting,
                level: xpSnapshot.level,
                rankTitle: xpSnapshot.rankTitle,
              ),
              const SizedBox(height: 16),
              _buildXpCard(xpSnapshot: xpSnapshot),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.query_stats,
                          color: _secondaryAccent,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Stats',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double cardWidth =
                            (constraints.maxWidth - 10) / 2;
                        final double childAspectRatio = cardWidth < 170
                            ? 1.25
                            : 1.4;

                        return GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          shrinkWrap: true,
                          childAspectRatio: childAspectRatio,
                          children: [
                            _buildStatTile(
                              label: 'Coins',
                              value: '$coins',
                              icon: Icons.monetization_on,
                              color: Colors.amber,
                            ),
                            _buildStatTile(
                              label: 'Current streak',
                              value: '$currentStreak',
                              icon: Icons.local_fire_department,
                              color: Colors.orangeAccent,
                            ),
                            _buildStatTile(
                              label: 'Longest streak',
                              value: '$longestStreak',
                              icon: Icons.emoji_events,
                              color: Colors.lightBlueAccent,
                            ),
                            _buildStatTile(
                              label: 'Perfect days',
                              value: '$perfectDays',
                              icon: Icons.star,
                              color: Colors.greenAccent,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _secondaryAccent.withValues(alpha: 0.24),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates, color: _secondaryAccent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Keep completing your checklist daily to level up faster and extend your streak.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
