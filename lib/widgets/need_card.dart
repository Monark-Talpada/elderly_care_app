// lib/widgets/need_card.dart
import 'package:flutter/material.dart';
import 'package:elderly_care_app/models/need_model.dart';

class NeedCard extends StatelessWidget {
  final DailyNeed need;
  final String seniorName;
  final Function(NeedStatus) onStatusChange;

  const NeedCard({
    Key? key,
    required this.need,
    required this.seniorName,
    required this.onStatusChange,
  }) : super(key: key);

  String _getFormattedDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getTypeColor() {
    switch (need.type) {
      case NeedType.medication:
        return Colors.blue;
      case NeedType.appointment:
        return Colors.purple;
      case NeedType.grocery:
        return Colors.green;
      case NeedType.other:
      default:
        return Colors.orange;
    }
  }

  String _getTypeText() {
    switch (need.type) {
      case NeedType.medication:
        return 'Medication';
      case NeedType.appointment:
        return 'Appointment';
      case NeedType.grocery:
        return 'Grocery';
      case NeedType.other:
      default:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getTypeColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getTypeText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    need.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Due: ${_getFormattedDate(need.dueDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'For: $seniorName',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              need.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => onStatusChange(NeedStatus.inProgress),
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => onStatusChange(NeedStatus.completed),
                  child: const Text('Complete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}