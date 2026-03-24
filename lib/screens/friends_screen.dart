import 'package:flutter/material.dart';

import '../models/friendship_model.dart';
import '../services/friend_service.dart';
import 'friend_requests_screen.dart';

/// Shows the current user's friends list and a search bar to find new friends.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();

  // Design constants — matches the rest of the app
  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _surfaceAltColor = Color(0xFF101522);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchError = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      final List<Map<String, dynamic>> results =
          await _friendService.searchUsersByEmail(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
        if (results.isEmpty) {
          _searchError = 'No users found for "$query".';
        }
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchError = 'Error searching. Please try again.';
      });
    }
  }

  Future<void> _sendRequest(Map<String, dynamic> user) async {
    final String receiverId = (user['uid'] ?? '').toString();
    final String receiverEmail = (user['email'] ?? '').toString();

    final String? error = await _friendService.sendFriendRequest(
      receiverId: receiverId,
      receiverEmail: receiverEmail,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Friend request sent to $receiverEmail'),
      ),
    );
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

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 15),
      ),
    );
  }

  Widget _buildFriendTile(Friendship friendship) {
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: _accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              friendship.friendEmail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.check_circle, color: _accentColor, size: 18),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> user) {
    final String email = (user['email'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _secondaryAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search,
                color: _secondaryAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              email,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          TextButton.icon(
            onPressed: () => _sendRequest(user),
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Add'),
            style: TextButton.styleFrom(
              foregroundColor: _accentColor,
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _backgroundColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // ── Header ─────────────────────────────────────────────────────────
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
                        'Friends',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Find friends and share your progress',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Requests button with badge
                StreamBuilder<List<dynamic>>(
                  stream: _friendService.watchIncomingRequests(),
                  builder: (context, snap) {
                    final int count = snap.data?.length ?? 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.inbox_rounded,
                              color: _secondaryAccent),
                          tooltip: 'Friend Requests',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const FriendRequestsScreen(),
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

          // ── Search bar ─────────────────────────────────────────────────────
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by email...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon:
                          const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _searchError = '';
                        });
                      },
                    )
                  : null,
            ),
            onSubmitted: _runSearch,
            onChanged: (value) {
              // Clear results when field is cleared
              if (value.isEmpty) {
                setState(() {
                  _searchResults = [];
                  _searchError = '';
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // ── Search Results ─────────────────────────────────────────────────
          if (_isSearching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _accentColor),
              ),
            )
          else if (_searchResults.isNotEmpty) ...[
            _buildSectionTitle('Search Results'),
            const SizedBox(height: 10),
            ..._searchResults.map(_buildSearchResultTile),
            const SizedBox(height: 20),
          ] else if (_searchError.isNotEmpty) ...[
            _buildEmptyCard(_searchError),
            const SizedBox(height: 20),
          ],

          // ── Friends List ───────────────────────────────────────────────────
          _buildSectionTitle('My Friends'),
          const SizedBox(height: 10),
          StreamBuilder<List<Friendship>>(
            stream: _friendService.watchFriends(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: _accentColor),
                  ),
                );
              }

              final List<Friendship> friends = snap.data ?? [];

              if (friends.isEmpty) {
                return _buildEmptyCard(
                  'No friends yet. Search for someone above to get started.',
                );
              }

              return Column(
                children: friends.map(_buildFriendTile).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
