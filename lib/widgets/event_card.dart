import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_management_mobile_app/data/database.dart';
import 'package:time_management_mobile_app/screens/today_tasks_screen.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const EventCard({
    super.key, 
    required this.event, 
    required this.onDelete,
    this.onTap,
  });
  String _formatDate(DateTime dt) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) {
      return "Today";
    }

    if (target == today.add(const Duration(days: 1))) {
      return "Tomorrow";
    }

    return DateFormat("MMM d").format(dt); // Feb 6
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('event_${event.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<Category?>(
              future: database.getCategoryById(event.categoryId),
              builder: (context, snapshot) {
                final category = snapshot.data;
                final categoryName = category?.name ?? "No Category";
                final categoryColor = category != null
                    ? Color(category.color)
                    : Colors.grey;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT — TODAY + TIME
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _formatDate(event.dueDate),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('HH:mm').format(event.startTime),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: categoryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // MIDDLE — vertical bar
                    Container(
                      width: 4,
                      height: 70, // adjust or use IntrinsicHeight for dynamic height
                      color: categoryColor,
                    ),

                    const SizedBox(width: 8),

                    // RIGHT — Category + Event title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: categoryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Event title
                          Text(
                            event.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    // RIGHT — Remind badge
                    if (event.isReminding) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Remind",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}


