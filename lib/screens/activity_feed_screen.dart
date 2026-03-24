import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/activity_post_model.dart';
import '../services/activity_service.dart';
import '../services/friend_service.dart';
import '../widgets/activity_post_widget.dart';
import 'shared_checklists_screen.dart';

/// Displays the activity feed for the current user and their friends.
class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  final ActivityService _activityService = ActivityService();
  final FriendService _friendService = FriendService();

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  List<ActivityPost> _posts = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // Fetch friend IDs first, then load the combined feed
      final List<String> friendIds = await _friendService.getFriendIds();
      final List<ActivityPost> posts =
          await _activityService.fetchFeed(friendIds);
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load feed. Pull down to retry.';
        });
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: _accentColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      color: _backgroundColor,
      child: RefreshIndicator(
        color: _accentColor,
        backgroundColor: _surfaceColor,
        onRefresh: _loadFeed,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF162033), Color(0xFF0F1420)],
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your activity and friends\' highlights',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  // Shared checklists inbox button with badge
                  StreamBuilder<List<dynamic>>(
                    stream:
                        _activityService.watchIncomingSharedChecklists(),
                    builder: (context, snap) {
                      final int count = snap.data?.length ?? 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.move_to_inbox_rounded,
                                color: _secondaryAccent),
                            tooltip: 'Shared Checklists',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SharedListScreen(),
                                ),
                              );
                            },
                          ),
                          if (count > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Feed ────────────────────────────────────────────────────────
            _buildSectionTitle('Recent Activity'),
            const SizedBox(height: 12),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _accentColor),
                ),
              )
            else if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              )
            else if (_posts.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.rss_feed_rounded,
                        color: Colors.white38, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No activity yet.',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Complete tasks, earn streaks, and add friends to see activity here.',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._posts.map(
                (post) => ActivityPostWidget(
                  post: post,
                  activityService: _activityService,
                  currentUserId: currentUserId,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
