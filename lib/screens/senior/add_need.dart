import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddNeedScreen extends StatefulWidget {
  final DailyNeed? need; // If provided, we are editing an existing need
  const AddNeedScreen({Key? key, this.need}) : super(key: key);

  @override
  _AddNeedScreenState createState() => _AddNeedScreenState();
}

class _AddNeedScreenState extends State<AddNeedScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  
  NeedType _selectedType = NeedType.other;
  bool _isRecurring = false;
  String _recurrenceRule = "Daily";
  
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.need != null;
    
    // Initialize controllers and values
    _titleController = TextEditingController(text: _isEditing ? widget.need!.title : '');
    _descriptionController = TextEditingController(text: _isEditing ? widget.need!.description : '');
    
    if (_isEditing) {
      _selectedDate = widget.need!.dueDate;
      _selectedTime = TimeOfDay.fromDateTime(widget.need!.dueDate);
      _selectedType = widget.need!.type;
      _isRecurring = widget.need!.isRecurring;
      _recurrenceRule = widget.need!.recurrenceRule ?? "Daily";
    } else {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  DateTime _combineDateAndTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _saveNeed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final dueDateTime = _combineDateAndTime();
      
      if (_isEditing && widget.need != null) {
        // Update existing need
        final updatedNeed = DailyNeed(
          id: widget.need!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          status: widget.need!.status,
          dueDate: dueDateTime,
          seniorId: currentUser.id,
          assignedToId: widget.need!.assignedToId,
          isRecurring: _isRecurring,
          recurrenceRule: _isRecurring ? _recurrenceRule : null,
          createdAt: widget.need!.createdAt,
        );
        
        final success = await databaseService.updateNeed(updatedNeed);
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Need updated successfully')),
          );
          Navigator.pop(context);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update need')),
          );
        }
      } else {
        // Create new need
        // In your need creation code:
          final newNeed = DailyNeed(
            id: '', // Will be updated after creation
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            type: _selectedType,
            status: NeedStatus.pending, // Use the enum value instead of a string
            dueDate: dueDateTime,
            seniorId: currentUser.id,
            isRecurring: _isRecurring,
            recurrenceRule: _isRecurring ? _recurrenceRule : null,
            createdAt: DateTime.now(),
          );
        
        final needId = await databaseService.addNeed(newNeed);
        
        if (needId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Need created successfully')),
          );
          Navigator.pop(context);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create need')),
          );
        }
      }
    } catch (e) {
      print('Error saving need: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Need' : 'Add New Need',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCard(
                        title: 'Need Details',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Title',
                                hintText: 'Enter need title',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.primaryColor,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.title,
                                  color: theme.primaryColor,
                                ),
                                filled: true,
                                fillColor: theme.primaryColor.withOpacity(0.05),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a title';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                hintText: 'Enter need description',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.primaryColor,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.description,
                                  color: theme.primaryColor,
                                ),
                                filled: true,
                                fillColor: theme.primaryColor.withOpacity(0.05),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a description';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCard(
                        title: 'Need Type',
                        child: _buildTypeSelector(),
                      ),
                      const SizedBox(height: 16),
                      _buildCard(
                        title: 'Schedule',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDateTimePicker(),
                            const SizedBox(height: 24),
                            _buildRecurrenceOptions(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _saveNeed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isEditing ? Icons.save : Icons.add_circle,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isEditing ? 'Update Need' : 'Create Need',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: NeedType.values.map((type) {
        final bool isSelected = type == _selectedType;
        final IconData icon;
        final String label;
        final Color color;

        switch (type) {
          case NeedType.medication:
            icon = Icons.medication;
            label = 'Medication';
            color = Colors.blue;
            break;
          case NeedType.appointment:
            icon = Icons.calendar_today;
            label = 'Appointment';
            color = Colors.purple;
            break;
          case NeedType.grocery:
            icon = Icons.shopping_basket;
            label = 'Grocery';
            color = Colors.green;
            break;
          case NeedType.other:
            icon = Icons.more_horiz;
            label = 'Other';
            color = Colors.orange;
            break;
        }

        return InkWell(
          onTap: () => setState(() => _selectedType = type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? color : Colors.grey[600],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateTimePicker() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: theme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectTime(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: theme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedTime.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceOptions() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text(
            'Recurring Need',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text(
            'Enable if this need repeats regularly',
            style: TextStyle(fontSize: 14),
          ),
          value: _isRecurring,
          onChanged: (value) => setState(() => _isRecurring = value),
          activeColor: theme.primaryColor,
          contentPadding: EdgeInsets.zero,
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Recurrence Pattern',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _recurrenceRule,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: "Daily", child: Text("Daily")),
                    DropdownMenuItem(value: "Weekly", child: Text("Weekly")),
                    DropdownMenuItem(value: "Monthly", child: Text("Monthly")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _recurrenceRule = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}