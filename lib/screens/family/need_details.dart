import 'package:flutter/material.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class NeedDetailsScreen extends StatelessWidget {
  final DailyNeed need;
  final String seniorName;
  final Function(NeedStatus) onStatusChange;

  const NeedDetailsScreen({
    Key? key,
    required this.need,
    required this.seniorName,
    required this.onStatusChange,
  }) : super(key: key);

  Color _getNeedTypeColor(NeedType type) {
    switch (type) {
      case NeedType.medication:
        return Colors.red;
      case NeedType.appointment:
        return Colors.purple;
      case NeedType.grocery:
        return Colors.green;
      case NeedType.other:
        return Colors.grey;
    }
  }

  IconData _getNeedTypeIcon(NeedType type) {
    switch (type) {
      case NeedType.medication:
        return Icons.medical_services;
      case NeedType.appointment:
        return Icons.calendar_today;
      case NeedType.grocery:
        return Icons.shopping_basket;
      case NeedType.other:
        return Icons.more_horiz;
    }
  }

  Color _getStatusColor(NeedStatus status) {
    switch (status) {
      case NeedStatus.pending:
        return Colors.orange;
      case NeedStatus.inProgress:
        return Colors.blue;
      case NeedStatus.completed:
        return Colors.green;
      case NeedStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(NeedStatus status) {
    switch (status) {
      case NeedStatus.pending:
        return Icons.pending;
      case NeedStatus.inProgress:
        return Icons.hourglass_empty;
      case NeedStatus.completed:
        return Icons.check_circle;
      case NeedStatus.cancelled:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type icon and title
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getNeedTypeColor(need.type),
                    _getNeedTypeColor(need.type).withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getNeedTypeIcon(need.type),
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              need.type.toString().split('.').last.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              need.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Status and Due Date
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(need.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(need.status),
                                size: 18,
                                color: _getStatusColor(need.status),
                              ),
                              SizedBox(width: 8),
                              Text(
                                need.status.toString().split('.').last.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(need.status),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: Text(
                            'Due Date',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: need.dueDate.isBefore(DateTime.now()) &&
                                        need.status != NeedStatus.completed
                                    ? Colors.red
                                    : Colors.grey[600],
                              ),
                              SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d, yyyy').format(need.dueDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: need.dueDate.isBefore(DateTime.now()) &&
                                          need.status != NeedStatus.completed
                                      ? Colors.red
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Description
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      need.description.isEmpty ? 'No description provided' : need.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Senior Information
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Senior Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: theme.primaryColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seniorName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Created on ${DateFormat('MMM d, yyyy').format(need.createdAt)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: need.status == NeedStatus.pending
          ? Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await onStatusChange(NeedStatus.completed);
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.check_circle),
                      label: Text('Mark as Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
} 