import 'package:flutter/material.dart';

import '../models/shared_checklist_model.dart';
import '../services/activity_service.dart';

/// Tab-level screen showing all checklists shared with the current user.
/// Each card can be previewed and applied to the user's task list,
/// with the option to wipe the current list or add on top.
class SharedListScreen extends StatelessWidget {
  const SharedListScreen({super.key});

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ActivityService service = ActivityService();

    return Container(
      color: _backgroundColor,
      child: StreamBuilder<List<SharedChecklist>>(
        stream: service.watchIncomingSharedChecklists(),
        builder: (context, snap) {
          final List<SharedChecklist> items = snap.data ?? [];
          final bool loading =
              snap.connectionState == ConnectionState.waiting && items.isEmpty;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // ── Header ────────────────────────────────────────────────────
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
                            'Shared List',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Checklists shared with you by friends',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _secondaryAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.move_to_inbox_rounded,
                          color: _secondaryAccent, size: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Section title ─────────────────────────────────────────────
              _buildSectionTitle('Shared Checklists'),
              const SizedBox(height: 12),

              // ── Content ───────────────────────────────────────────────────
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: _accentColor),
                  ),
                )
              else if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.inbox_rounded,
                          color: Colors.white38, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'No shared checklists yet.',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'When a friend shares a checklist with you, it will appear here.',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...items.map(
                  (share) => _SharedChecklistCard(
                    share: share,
                    service: service,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Card widget ──────────────────────────────────────────────────────────────

class _SharedChecklistCard extends StatefulWidget {
  final SharedChecklist share;
  final ActivityService service;

  const _SharedChecklistCard({
    required this.share,
    required this.service,
  });

  @override
  State<_SharedChecklistCard> createState() => _SharedChecklistCardState();
}

class _SharedChecklistCardState extends State<_SharedChecklistCard> {
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _surfaceAltColor = Color(0xFF101522);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  bool _expanded = false;
  bool _loading = false;

  /// Shows a dialog asking whether to wipe the current list or add on top,
  /// then calls the service accordingly.
  Future<void> _showApplyDialog() async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text(
          'Apply "${widget.share.checklistTitle}"',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'How would you like to apply this checklist?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          // Cancel
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          // Add on top
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'add'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentColor,
              side: const BorderSide(color: _accentColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add to List'),
          ),
          // Wipe and replace
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'wipe'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _secondaryAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Replace List',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (choice == null) return; // cancelled

    setState(() => _loading = true);
    await widget.service.acceptSharedChecklist(
      widget.share,
      wipeFirst: choice == 'wipe',
    );
    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          choice == 'wipe'
              ? '"${widget.share.checklistTitle}" replaced your list!'
              : '"${widget.share.checklistTitle}" added to your list!',
        ),
      ),
    );
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    await widget.service.declineSharedChecklist(widget.share.id);
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checklist declined.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SharedChecklist share = widget.share;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _secondaryAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded,
                      color: _secondaryAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        share.checklistTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'From ${share.senderEmail}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${share.tasks.length} task(s)',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Expand/collapse preview
                IconButton(
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                  ),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          // ── Task preview (expandable) ────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surfaceAltColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...share.tasks.take(8).map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                const Icon(Icons.circle,
                                    size: 5, color: _accentColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (t['taskName'] ?? '').toString(),
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13),
                                  ),
                                ),
                                Text(
                                  (t['category'] ?? '').toString(),
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (share.tasks.length > 8)
                      Text(
                        '+ ${share.tasks.length - 8} more...',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),

          // ── Action buttons ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _accentColor),
                  )
                : Row(
                    children: [
                      // Decline
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _decline,
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
                      // Apply — opens the wipe/add dialog
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _showApplyDialog,
                          icon: const Icon(Icons.playlist_add_rounded,
                              size: 18),
                          label: const Text(
                            'Apply to My List',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
