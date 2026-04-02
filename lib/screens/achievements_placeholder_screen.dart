import 'package:flutter/material.dart';

class AchievementsPlaceholderScreen extends StatelessWidget {
  const AchievementsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.emoji_events_outlined,
                size: 48,
                color: Color(0xFFFFC857),
              ),
              SizedBox(height: 16),
              Text(
                'Achievements are coming soon.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Keep completing your checklist and building streaks.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}