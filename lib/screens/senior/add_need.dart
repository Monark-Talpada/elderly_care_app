import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final dueDateTime = _combineDateAndTime();
      
      if (_isEditing) {
        // Update existing need
        final updatedNeed = widget.need!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          dueDate: dueDateTime,
          isRecurring: _isRecurring,
          recurrenceRule: _isRecurring ? _recurrenceRule : null,
        );
        
        await databaseService.updateNeed(updatedNeed);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Need updated successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new need
        final newNeed = DailyNeed(
          id: const Uuid().v4(),
          seniorId: currentUser.id, // Changed from uid to id
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          status: NeedStatus.pending,
          dueDate: dueDateTime, // Combine date and time
          createdAt: DateTime.now(),
          isRecurring: _isRecurring,
          recurrenceRule: _isRecurring ? _recurrenceRule : null,
        );
        
        await databaseService.addNeed(newNeed); // Changed from createNeed to addNeed
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Need created successfully')),
          );
          Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Need' : 'Add New Need'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
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
                    const SizedBox(height: 16),
                    _buildTypeSelector(),
                    const SizedBox(height: 16),
                    _buildDateTimePicker(),
                    const SizedBox(height: 16),
                    _buildRecurrenceOptions(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveNeed,
                        child: Text(
                          _isEditing ? 'Update Need' : 'Create Need',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Need Type',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: [
            _buildTypeChip(
              label: 'Medication',
              icon: Icons.medication,
              type: NeedType.medication,
              color: Colors.blue,
            ),
            _buildTypeChip(
              label: 'Appointment',
              icon: Icons.calendar_today,
              type: NeedType.appointment,
              color: Colors.purple,
            ),
            _buildTypeChip(
              label: 'Grocery',
              icon: Icons.shopping_basket,
              type: NeedType.grocery,
              color: Colors.green,
            ),
            _buildTypeChip(
              label: 'Other',
              icon: Icons.more_horiz,
              type: NeedType.other,
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required NeedType type,
    required Color color,
  }) {
    final isSelected = _selectedType == type;
    
    return FilterChip(
      label: Text(label),
      avatar: Icon(
        icon,
        color: isSelected ? Colors.white : color,
        size: 18,
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedType = type;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Due Date and Time',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  child: Text(
                    DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(
                    _selectedTime.format(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecurrenceOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value ?? false;
                });
              },
            ),
            const Text('This is a recurring need'),
          ],
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 8),
          Text(
            'Repeat',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _recurrenceRule,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.repeat),
            ),
            items: [
              'Daily',
              'Weekly',
              'Every 2 weeks',
              'Monthly',
            ].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() {
                  _recurrenceRule = newValue;
                });
              }
            },
          ),
        ],
      ],
    );
  }
}