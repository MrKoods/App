import 'package:flutter/material.dart';

import '../models/activity_post_model.dart';
import '../models/reaction_model.dart';
import '../services/activity_service.dart';

/// A card widget that displays a single activity post with reactions.
class ActivityPostWidget extends StatelessWidget {
  final ActivityPost post;
  final ActivityService activityService;
  final String currentUserId;

  const ActivityPostWidget({
    super.key,
    required this.post,
    required this.activityService,
    required this.currentUserId,
  });

  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  // Maps each activity type to an icon and color
  IconData _typeIcon(String type) {
    switch (type) {
      case 'task_completed':
        return Icons.task_alt;
      case 'checklist_completed':
        return Icons.checklist_rounded;
      case 'streak_milestone':
        return Icons.local_fire_department;
      case 'reward_redeemed':
        return Icons.emoji_events;
      case 'checklist_shared':
        return Icons.share_rounded;
      default:
        return Icons.star;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'task_completed':
        return _accentColor;
      case 'checklist_completed':
        return const Color(0xFF8CFF98);
      case 'streak_milestone':
        return Colors.orangeAccent;
      case 'reward_redeemed':
        return _secondaryAccent;
      case 'checklist_shared':
        return const Color(0xFF6EA8FE);
      default:
        return Colors.white54;
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final DateTime local = dt.toLocal();
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(local);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Post header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with type icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _typeColor(post.type).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _typeIcon(post.type),
                    color: _typeColor(post.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show "You" for own posts, email otherwise
                      Text(
                        post.userId == currentUserId ? 'You' : post.userEmail,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        post.message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Timestamp
                Text(
                  _formatTime(post.timestamp),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Reactions row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: StreamBuilder<List<Reaction>>(
              stream: activityService.watchReactions(post.id),
              builder: (context, snap) {
                final List<Reaction> reactions = snap.data ?? [];
                return _ReactionsRow(
                  postId: post.id,
                  reactions: reactions,
                  currentUserId: currentUserId,
                  activityService: activityService,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The row of reaction buttons shown at the bottom of each post.
class _ReactionsRow extends StatelessWidget {
  final String postId;
  final List<Reaction> reactions;
  final String currentUserId;
  final ActivityService activityService;

  const _ReactionsRow({
    required this.postId,
    required this.reactions,
    required this.currentUserId,
    required this.activityService,
  });

  static const Color _surfaceAltColor = Color(0xFF101522);
  static const Color _accentColor = Color(0xFF55E6C1);

  // The four supported reaction types with emoji labels
  static const List<({String type, String emoji})> _reactionTypes = [
    (type: 'like', emoji: '👍'),
    (type: 'clap', emoji: '👏'),
    (type: 'fire', emoji: '🔥'),
    (type: 'goodjob', emoji: '⭐'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _reactionTypes.map((r) {
        // Count how many users reacted with this type
        final int count =
            reactions.where((rx) => rx.reactionType == r.type).length;
        final bool myReaction = reactions.any(
          (rx) => rx.reactionType == r.type && rx.userId == currentUserId,
        );

        return GestureDetector(
          onTap: () async {
            if (myReaction) {
              await activityService.removeReaction(
                postId: postId,
                reactionType: r.type,
              );
            } else {
              await activityService.addReaction(
                postId: postId,
                reactionType: r.type,
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: myReaction
                  ? _accentColor.withValues(alpha: 0.18)
                  : _surfaceAltColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: myReaction
                    ? _accentColor.withValues(alpha: 0.5)
                    : Colors.white12,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.emoji, style: const TextStyle(fontSize: 14)),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: myReaction ? _accentColor : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
