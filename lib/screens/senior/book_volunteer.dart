import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:elderly_care_app/services/database_service.dart';

class BookVolunteerScreen extends StatefulWidget {
  final String volunteerId;
  final DailyNeed? need;

  const BookVolunteerScreen({
    Key? key,
    required this.volunteerId,
    this.need,
  }) : super(key: key);

  @override
  _BookVolunteerScreenState createState() => _BookVolunteerScreenState();
}

class _BookVolunteerScreenState extends State<BookVolunteerScreen> {
  late DatabaseService _databaseService;
  Volunteer? _volunteer;
  SeniorCitizen? _senior;
  bool _isLoading = true;
  Map<String, List<TimeSlot>> _availableSlots = {};
  String? _selectedDay;
  TimeSlot? _selectedTimeSlot;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load volunteer data
      _volunteer = await _databaseService.getVolunteer(widget.volunteerId);
      
      // Load senior data (assuming current user is senior)
      _senior = await _databaseService.getCurrentSenior();
      
      // Filter slots that are not booked
      _availableSlots = {};
      _volunteer?.availability.forEach((day, slots) {
        List<TimeSlot> availableSlots = slots.where((slot) => !slot.isBooked).toList();
        if (availableSlots.isNotEmpty) {
          _availableSlots[day] = availableSlots;
        }
      });
      
      // Set default selected day if available
      if (_availableSlots.isNotEmpty) {
        _selectedDay = _availableSlots.keys.first;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _bookAppointment() async {
    if (_senior == null || _volunteer == null || _selectedTimeSlot == null || _selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // First, update the volunteer's time slot
      bool slotUpdated = await _databaseService.updateVolunteerTimeSlot(
        _volunteer!.id,
        _selectedDay!,
        _selectedTimeSlot!,
        true, // isBooked = true
        _senior!.id, // bookedById
      );
      
      if (!slotUpdated) {
        throw Exception('Failed to update volunteer time slot');
      }
      
      // Calculate appointment date by combining the day and time
      DateTime appointmentDate = _selectedTimeSlot!.startTime;
      
      // Create description using the notes field and need details if available
      String description = widget.need != null 
          ? '${widget.need!.title}: ${widget.need!.description}\n${_notesController.text}' 
          : _notesController.text;
      
      // Book appointment using the method from DatabaseService
      String? appointmentId = await _databaseService.bookAppointment(
        seniorId: _senior!.id,
        volunteerId: _volunteer!.id,
        appointmentDate: appointmentDate,
        description: description,
      );
      
      if (appointmentId == null) {
        throw Exception('Failed to create appointment');
      }

      // If this is for a specific need, update the need
      if (widget.need != null) {
        await _databaseService.updateNeed(
          widget.need!.copyWith(
            assignedToId: _volunteer!.id,
            status: NeedStatus.inProgress,
          ),
        );
      }

      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking appointment: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Volunteer'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _volunteer == null
              ? const Center(child: Text('Volunteer not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Volunteer info card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundImage: _volunteer?.photoUrl != null
                                        ? NetworkImage(_volunteer!.photoUrl!)
                                        : null,
                                    child: _volunteer?.photoUrl == null
                                        ? Text(_volunteer!.name[0])
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _volunteer!.name,
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        if (_volunteer!.isVerified)
                                          Row(
                                            children: [
                                              const Icon(Icons.verified, color: Colors.blue, size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Verified Volunteer',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        if (_volunteer!.rating != null)
                                          Row(
                                            children: [
                                              Icon(Icons.star, color: Colors.amber, size: 16),
                                              SizedBox(width: 4),
                                              Text(
                                                '${_volunteer!.rating!.toStringAsFixed(1)} (${_volunteer!.ratingCount})',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_volunteer!.bio != null) ...[
                                Text(
                                  'About',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(_volunteer!.bio!),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                'Skills',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _volunteer!.skills.map((skill) {
                                  return Chip(label: Text(skill));
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Need information if provided
                      if (widget.need != null) ...[
                        Text(
                          'Need Details',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.need!.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(widget.need!.description),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Due: ${DateFormat.yMMMd().format(widget.need!.dueDate)}'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Chip(
                                  label: Text(widget.need!.type.toString().split('.').last),
                                  backgroundColor: _getColorForNeedType(widget.need!.type),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Availability selection
                      Text(
                        'Available Time Slots',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      
                      if (_availableSlots.isEmpty) ...[
                        const Center(
                          child: Text('No available time slots'),
                        )
                      ] else ...[
                        // Day selection
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Day',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedDay,
                          items: _availableSlots.keys.map((day) {
                            return DropdownMenuItem<String>(
                              value: day,
                              child: Text(day),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDay = value;
                              _selectedTimeSlot = null;
                            });
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Time slot selection
                        if (_selectedDay != null) ...[
                          Text(
                            'Select Time Slot',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableSlots[_selectedDay]!.map((slot) {
                              final timeRange = '${DateFormat.jm().format(slot.startTime)} - ${DateFormat.jm().format(slot.endTime)}';
                              return ChoiceChip(
                                label: Text(timeRange),
                                selected: _selectedTimeSlot == slot,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTimeSlot = selected ? slot : null;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Notes field
                        TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Additional Notes',
                            hintText: 'Add any specific details or requests for the volunteer',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Book button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedTimeSlot != null ? _bookAppointment : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Book Appointment'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  // Helper method to get color for need type
  Color _getColorForNeedType(NeedType type) {
    switch (type) {
      case NeedType.medication:
        return Colors.blue.shade100;
      case NeedType.appointment:
        return Colors.purple.shade100;
      case NeedType.grocery:
        return Colors.green.shade100;
      case NeedType.other:
        return Colors.orange.shade100;
    }
  }
}