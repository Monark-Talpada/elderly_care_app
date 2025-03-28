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
      _availability = widget.volunteer.availability;
    });
    
    await Future.delayed(const Duration(milliseconds: 300));
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
    );

    setState(() {
      if (_availability.containsKey(dayKey)) {
        _availability[dayKey]!.add(newSlot);
      } else {
        _availability[dayKey] = [newSlot];
      }
    });

    await _updateAvailability();
  }

  Future<void> _updateAvailability() async {
    try {
      final Volunteer updatedVolunteer = widget.volunteer.copyWith(
        availability: _availability,
      );
      
      await _databaseService.updateVolunteerAvailability(
        updatedVolunteer.id, 
        updatedVolunteer.availability
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability updated successfully')),
      );
    } catch (e) {
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

    await _updateAvailability();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Availability'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadAvailability,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildCalendarSection(constraints),
                      ),
                      SliverToBoxAdapter(
                        child: _buildTimeSlotHeader(),
                      ),
                      _buildTimeSlotsList(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCalendarSection(BoxConstraints constraints) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: constraints.maxHeight * 0.4,
        minHeight: constraints.maxHeight * 0.3,
      ),
      child: TableCalendar(
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          headerPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.blue.shade200,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
          ),
        ),
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
    );
  }

  Widget _buildTimeSlotHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Available Time Slots for ${DateFormat('MMM dd, yyyy').format(_selectedDay)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _addTimeSlot,
            child: const Text('Add Slot'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsList() {
    final String dayKey = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final List<TimeSlot> daySlots = _availability[dayKey] ?? [];

    if (daySlots.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'No availability added for this day. Tap "Add Slot" to add time slots.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
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
        childCount: daySlots.length,
      ),
    );
  }
}