import 'package:flutter/material.dart';

import '../models/task_model.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onFinish;
  final VoidCallback? onReset;
  final ValueChanged<bool?>? onCheckboxChanged;
  final Duration? elapsedDuration;

  const TaskTile({
    super.key,
    required this.task,
    this.onTap,
    this.onStart,
    this.onFinish,
    this.onReset,
    this.onCheckboxChanged,
    this.elapsedDuration,
  });

  Color _getCategoryColor(String category) {
    if (category == 'School') {
      return const Color(0xFF6EA8FE);
    } else if (category == 'Health') {
      return const Color(0xFF5CF2B5);
    } else if (category == 'Productivity') {
      return const Color(0xFFFF9F5A);
    } else if (category == 'Personal') {
      return const Color(0xFFFF6FAE);
    } else {
      return Colors.white70;
    }
  }

  Color _getStatusColor() {
    if (task.isInProgress) {
      return const Color(0xFF55E6C1);
    }

    if (task.isDone) {
      return const Color(0xFF8CFF98);
    }

    return const Color(0xFFFFC857);
  }

  Color _getCardBackground() {
    final Color categoryColor = _getCategoryColor(task.category);
    return Color.alphaBlend(categoryColor.withValues(alpha: 0.12), const Color(0xFF121826));
  }

  String _formatStatus(String status) {
    if (status == 'inProgress') {
      return 'In progress';
    }

    if (status == 'completed') {
      return 'Completed';
    }

    return 'Not started';
  }

  String _formatElapsed(Duration value) {
    final String hours = value.inHours.toString().padLeft(2, '0');
    final String minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _completedDurationText() {
    final int minutes = (task.durationSeconds / 60).ceil();
    return 'Completed in $minutes min';
  }

  Widget _buildCheckbox() {
    return Checkbox(
      value: task.completed,
      activeColor: Colors.amber,
      checkColor: Colors.black,
      onChanged: task.completed ? null : onCheckboxChanged,
    );
  }

  Widget _buildLegacyChecklistTile() {
    return ListTile(
      leading: _buildCheckbox(),
      title: Text(
        task.title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          decorationColor: Colors.white70,
        ),
      ),
      subtitle: Text(
        task.category,
        style: TextStyle(
          color: _getCategoryColor(task.category),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionArea() {
    if (task.isInProgress) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Time: ${_formatElapsed(elapsedDuration ?? Duration.zero)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF55E6C1),
              foregroundColor: Colors.black,
            ),
            child: const Text('Finish'),
          ),
        ],
      );
    }

    if (task.isDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _completedDurationText(),
            style: const TextStyle(
              color: Color(0xFF8CFF98),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onReset,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('Reset'),
          ),
        ],
      );
    }

    return ElevatedButton(
      onPressed: onStart,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFC857),
        foregroundColor: Colors.black,
      ),
      child: const Text('Start'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool useLegacyChecklist = onStart == null && onFinish == null && onTap != null;

    return Card(
      color: _getCardBackground(),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getStatusColor().withValues(alpha: 0.35),
        ),
      ),
      child: useLegacyChecklist
          ? _buildLegacyChecklistTile()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: _buildCheckbox(),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      task.taskName,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        decoration:
                                            task.completed ? TextDecoration.lineThrough : null,
                                        decorationColor: Colors.white54,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor().withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _formatStatus(task.status),
                                    style: TextStyle(
                                      color: _getStatusColor(),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(task.category).withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    task.category,
                                    style: TextStyle(
                                      color: _getCategoryColor(task.category),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildActionArea(),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}