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
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: const Text('Availability'),
            elevation: 0,
            backgroundColor: const Color(0xFF4A90E2),
            foregroundColor: Colors.white,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadAvailability,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF4A90E2),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: _buildCalendarSection(constraints),
                        ),
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
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
          rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: const TextStyle(color: Colors.white),
          weekendTextStyle: const TextStyle(color: Colors.white70),
          outsideTextStyle: const TextStyle(color: Colors.white30),
          todayDecoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(color: Color(0xFF4A90E2)),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMM dd, yyyy').format(_selectedDay),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C3E50),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _addTimeSlot,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time,
                size: 48,
                color: const Color(0xFF4A90E2).withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              const Text(
                'No time slots added',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final TimeSlot slot = daySlots[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                '${DateFormat.jm().format(slot.startTime)} - ${DateFormat.jm().format(slot.endTime)}',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF2C3E50),
                ),
              ),
              trailing: slot.isBooked
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE74C3C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Reserved',
                        style: TextStyle(
                          color: Color(0xFFE74C3C),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeTimeSlot(dayKey, index),
                      color: const Color(0xFF95A5A6),
                    ),
            ),
          );
        },
        childCount: daySlots.length,
      ),
    );
  }
}