// lib/widgets/need_card.dart
import 'package:flutter/material.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:intl/intl.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

class NeedCard extends StatelessWidget {
  final DailyNeed need;
  final String seniorName;
  final Function(NeedStatus) onStatusChange;
    final bool isHighlighted;


  const NeedCard({
    Key? key,
    required this.need,
    required this.seniorName,
    required this.onStatusChange,
    this.isHighlighted = false,

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
      elevation: isHighlighted ? 8 : 4,
      color: isHighlighted ? Colors.yellow[100] : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted ? BorderSide(color: Colors.yellow[700]!, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              need.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Description: ${need.description.isEmpty ? "None" : need.description}'),
            Text('Type: ${need.type.name.capitalize()}'),
            Text('Status: ${need.status.name.capitalize()}'),
            Text('Due: ${DateFormat('MMM d, yyyy').format(need.dueDate)}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (need.status == NeedStatus.pending)
                  TextButton(
                    onPressed: () => onStatusChange(NeedStatus.inProgress),
                    child: const Text('Accept'),
                  ),
                if (need.status == NeedStatus.inProgress)
                  TextButton(
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