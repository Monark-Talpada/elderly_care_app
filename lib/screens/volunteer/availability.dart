import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:table_calendar/table_calendar.dart';

class AvailabilityScreen extends StatefulWidget {
  final Volunteer volunteer;

  const AvailabilityScreen({Key? key, required this.volunteer}) : super(key: key);

  @override
  _AvailabilityScreenState createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  final DatabaseService _databaseService = DatabaseService();
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  final TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  final TimeOfDay _endTime = TimeOfDay(hour: 17, minute: 0);
  Map<String, List<TimeSlot>> _availability = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Fetch the latest availability data from Firestore
      final volunteerDoc = await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(widget.volunteer.id)
          .get();
      
      if (volunteerDoc.exists && volunteerDoc.data()?['availability'] != null) {
        // Convert Firestore data to Map<String, List<TimeSlot>>
        final Map<String, dynamic> availabilityData = 
            Map<String, dynamic>.from(volunteerDoc.data()?['availability'] ?? {});
        
        _availability = {};
        
        availabilityData.forEach((key, value) {
          if (value is List) {
            _availability[key] = (value as List)
                .map((slot) => TimeSlot.fromMap(Map<String, dynamic>.from(slot)))
                .toList();
          }
        });
      } else {
        _availability = widget.volunteer.availability;
      }
    } catch (e) {
      print('Error loading availability: $e');
      _availability = widget.volunteer.availability;
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _addTimeSlot() async {
    final TimeOfDay? pickedStartTime = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    
    if (pickedStartTime == null) return;

    final TimeOfDay? pickedEndTime = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    
    if (pickedEndTime == null) return;

    final DateTime startDateTime = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      pickedStartTime.hour,
      pickedStartTime.minute,
    );

    final DateTime endDateTime = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      pickedEndTime.hour,
      pickedEndTime.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final String dayKey = DateFormat('yyyy-MM-dd').format(_selectedDay);

    final TimeSlot newSlot = TimeSlot(
      startTime: startDateTime,
      endTime: endDateTime,
      isBooked: false,
    );

    setState(() {
      if (_availability.containsKey(dayKey)) {
        _availability[dayKey]!.add(newSlot);
      } else {
        _availability[dayKey] = [newSlot];
      }
    });

    // Update in Firestore
    await _updateAvailability();
  }

  Future<void> _updateAvailability() async {
    try {
      // Convert TimeSlot objects to Firestore-friendly format
      final Map<String, List<Map<String, dynamic>>> firebaseAvailability = {};
      
      _availability.forEach((day, slots) {
        firebaseAvailability[day] = slots.map((slot) => slot.toMap()).toList();
      });
      
      // Update directly in Firestore
      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(widget.volunteer.id)
          .update({
            'availability': firebaseAvailability,
          });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability updated successfully')),
      );
    } catch (e) {
      print('Error updating availability: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  Future<void> _removeTimeSlot(String dayKey, int index) async {
    setState(() {
      _availability[dayKey]!.removeAt(index);
      if (_availability[dayKey]!.isEmpty) {
        _availability.remove(dayKey);
      }
    });

    // Update in Firestore
    await _updateAvailability();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Availability'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(const Duration(days: 90)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Time Slots for ${DateFormat('MMM dd, yyyy').format(_selectedDay)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _addTimeSlot,
                        child: const Text('Add Slot'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildTimeSlotsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildTimeSlotsList() {
    final String dayKey = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final List<TimeSlot> daySlots = _availability[dayKey] ?? [];

    if (daySlots.isEmpty) {
      return const Center(
        child: Text('No availability added for this day. Tap "Add Slot" to add time slots.'),
      );
    }

    return ListView.builder(
      itemCount: daySlots.length,
      itemBuilder: (context, index) {
        final TimeSlot slot = daySlots[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(
              '${DateFormat.jm().format(slot.startTime)} - ${DateFormat.jm().format(slot.endTime)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              slot.isBooked ? 'Booked' : 'Available',
              style: TextStyle(
                color: slot.isBooked ? Colors.red : Colors.green,
              ),
            ),
            trailing: slot.isBooked
                ? const Chip(
                    label: Text('Reserved'),
                    backgroundColor: Colors.amber,
                  )
                : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeTimeSlot(dayKey, index),
                  ),
          ),
        );
      },
    );
  }
}

// Make sure your TimeSlot class has proper toJson and fromJson methods:
// Add these to your TimeSlot class in volunteer_model.dart if they don't exist

/*
class TimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isBooked;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isBooked': isBooked,
    };
  }

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: (json['startTime'] as Timestamp).toDate(),
      endTime: (json['endTime'] as Timestamp).toDate(),
      isBooked: json['isBooked'] ?? false,
    );
  }
}
*/