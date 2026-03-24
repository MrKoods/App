import 'package:flutter/material.dart';

import '../models/friendship_model.dart';
import '../models/preset_model.dart';
import '../services/activity_service.dart';
import '../services/friend_service.dart';

/// Lets the user pick a friend to share a checklist (preset) with.
class ShareChecklistScreen extends StatefulWidget {
  final TaskPreset preset;

  const ShareChecklistScreen({super.key, required this.preset});

  @override
  State<ShareChecklistScreen> createState() => _ShareChecklistScreenState();
}

class _ShareChecklistScreenState extends State<ShareChecklistScreen> {
  final FriendService _friendService = FriendService();
  final ActivityService _activityService = ActivityService();

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _surfaceAltColor = Color(0xFF101522);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  bool _isSending = false;

  Future<void> _handleShare(Friendship friend) async {
    setState(() => _isSending = true);

    final String? error = await _activityService.shareChecklist(
      preset: widget.preset,
      receiverId: friend.friendId,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Checklist shared with ${friend.friendEmail}!',
        ),
      ),
    );

    if (error == null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Share Checklist'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Friendship>>(
        stream: _friendService.watchFriends(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _accentColor),
            );
          }

          final List<Friendship> friends = snap.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Checklist preview card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: _accentColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.share_rounded,
                            color: _accentColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Sharing',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.preset.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.preset.tasks.length} task(s)',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    ...widget.preset.tasks.take(5).map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.circle,
                                    size: 5, color: _accentColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.taskName,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (widget.preset.tasks.length > 5)
                      Text(
                        '+ ${widget.preset.tasks.length - 5} more...',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Friends list
              if (friends.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'You have no friends yet. Add friends from the Friends tab first.',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                )
              else ...[
                const Text(
                  'Send to a friend:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...friends.map(
                  (friend) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _surfaceAltColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person,
                              color: _accentColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            friend.friendEmail,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: _accentColor, strokeWidth: 2),
                              )
                            : ElevatedButton(
                                onPressed: () => _handleShare(friend),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _secondaryAccent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                                child: const Text('Share'),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
