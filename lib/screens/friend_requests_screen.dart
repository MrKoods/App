import 'package:flutter/material.dart';

import '../models/friend_request_model.dart';
import '../services/friend_service.dart';

/// Shows incoming and outgoing friend requests for the current user.
class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _surfaceAltColor = Color(0xFF101522);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FriendService friendService = FriendService();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Friend Requests'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Incoming Requests ──────────────────────────────────────────────
          _buildSectionTitle('Incoming Requests'),
          const SizedBox(height: 12),
          StreamBuilder<List<FriendRequest>>(
            stream: friendService.watchIncomingRequests(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: _accentColor),
                  ),
                );
              }

              final List<FriendRequest> requests = snap.data ?? [];

              if (requests.isEmpty) {
                return _buildEmptyCard('No pending friend requests.');
              }

              return Column(
                children: requests
                    .map((req) => _buildIncomingTile(context, req, friendService))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Outgoing Requests ──────────────────────────────────────────────
          _buildSectionTitle('Sent Requests'),
          const SizedBox(height: 12),
          StreamBuilder<List<FriendRequest>>(
            stream: friendService.watchOutgoingRequests(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }

              final List<FriendRequest> sent = snap.data ?? [];

              if (sent.isEmpty) {
                return _buildEmptyCard('No outgoing requests.');
              }

              return Column(
                children: sent
                    .map((req) => _buildOutgoingTile(req))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingTile(
    BuildContext context,
    FriendRequest request,
    FriendService service,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _secondaryAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: _secondaryAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  request.senderEmail,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await service.declineFriendRequest(request.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Declined request from ${request.senderEmail}'),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await service.acceptFriendRequest(request);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Now friends with ${request.senderEmail}!'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingTile(FriendRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              color: _accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pending, color: _accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.receiverEmail,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Pending...',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Sent',
              style: TextStyle(
                  color: _accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
