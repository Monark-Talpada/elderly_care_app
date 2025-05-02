import 'package:flutter/material.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:intl/intl.dart';

class NeedDetailsScreen extends StatelessWidget {
  final DailyNeed need;

  const NeedDetailsScreen({super.key, required this.need});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Need Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Need type and status
            Row(
              children: [
                _buildTypeIcon(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        need.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    need.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Details grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildDetailCard(
                  context,
                  'Due Date',
                  DateFormat('MMM d, yyyy').format(need.dueDate),
                  Icons.calendar_today,
                ),
                _buildDetailCard(
                  context,
                  'Time',
                  DateFormat('h:mm a').format(need.dueDate),
                  Icons.access_time,
                ),
                _buildDetailCard(
                  context,
                  'Category',
                  need.type.toString().split('.').last,
                  Icons.category,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Actions
            if (need.status != NeedStatus.completed && need.status != NeedStatus.cancelled)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement edit functionality
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Need'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement cancel functionality
                      },
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Need'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (need.type) {
      case NeedType.medication:
        icon = Icons.medication;
        color = Colors.blue;
        break;
      case NeedType.appointment:
        icon = Icons.calendar_today;
        color = Colors.purple;
        break;
      case NeedType.grocery:
        icon = Icons.shopping_basket;
        color = Colors.green;
        break;
      case NeedType.other:
        icon = Icons.more_horiz;
        color = Colors.orange;
        break;
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          color: color,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;
    IconData icon;

    switch (need.status) {
      case NeedStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      case NeedStatus.inProgress:
        color = Colors.blue;
        label = 'In Progress';
        icon = Icons.refresh;
        break;
      case NeedStatus.completed:
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case NeedStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
} 