import 'package:flutter/material.dart';

class DailySummaryWidget extends StatelessWidget {
  final int tasksCompletedToday;
  final int totalFocusTimeSeconds;
  final int coinsEarnedToday;
  final int currentStreak;

  const DailySummaryWidget({
    super.key,
    required this.tasksCompletedToday,
    required this.totalFocusTimeSeconds,
    required this.coinsEarnedToday,
    required this.currentStreak,
  });

  String _formatFocusTime(int totalSeconds) {
    final Duration duration = Duration(seconds: totalSeconds);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${duration.inMinutes} min';
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildSummaryItem(
                label: 'Tasks today',
                value: '$tasksCompletedToday',
                icon: Icons.check_circle,
                color: Colors.greenAccent,
              ),
              const SizedBox(width: 12),
              _buildSummaryItem(
                label: 'Focus time',
                value: _formatFocusTime(totalFocusTimeSeconds),
                icon: Icons.timer,
                color: Colors.lightBlueAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem(
                label: 'Coins earned',
                value: '+$coinsEarnedToday',
                icon: Icons.monetization_on,
                color: Colors.amber,
              ),
              const SizedBox(width: 12),
              _buildSummaryItem(
                label: 'Current streak',
                value: '$currentStreak',
                icon: Icons.local_fire_department,
                color: Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
