import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:flutter/services.dart';

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

class _BookVolunteerScreenState extends State<BookVolunteerScreen> with SingleTickerProviderStateMixin {
  late DatabaseService _databaseService;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  Volunteer? _volunteer;
  SeniorCitizen? _senior;
  bool _isLoading = true;
  Map<String, List<TimeSlot>> _availableSlots = {};
  String? _selectedDay;
  TimeSlot? _selectedTimeSlot;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _volunteer = await _databaseService.getVolunteer(widget.volunteerId);
      _senior = await _databaseService.getCurrentSenior();
      
      _availableSlots = {};
      _volunteer?.availability.forEach((day, slots) {
        List<TimeSlot> availableSlots = slots.where((slot) => !slot.isBooked).toList();
        if (availableSlots.isNotEmpty) {
          _availableSlots[day] = availableSlots;
        }
      });
      
      if (_availableSlots.isNotEmpty) {
        _selectedDay = _availableSlots.keys.first;
      }

      // Start fade-in animation
      _animationController.forward();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
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

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your location')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool slotUpdated = await _databaseService.updateVolunteerTimeSlot(
        _volunteer!.id,
        _selectedDay!,
        _selectedTimeSlot!,
        true,
        _senior!.id,
      );
      
      if (!slotUpdated) {
        throw Exception('Failed to update volunteer time slot');
      }
      
      DateTime appointmentDate = _selectedTimeSlot!.startTime;
      String description = widget.need != null 
          ? '${widget.need!.title}: ${widget.need!.description}\nLocation: ${_locationController.text.trim()}\n${_notesController.text}' 
          : 'Location: ${_locationController.text.trim()}\n${_notesController.text}';
      
      String? appointmentId = await _databaseService.bookAppointment(
        seniorId: _senior!.id,
        volunteerId: _volunteer!.id,
        appointmentDate: appointmentDate,
        description: description,
      );
      
      if (appointmentId == null) {
        throw Exception('Failed to create appointment');
      }

      if (widget.need != null) {
        await _databaseService.updateNeed(
          widget.need!.copyWith(
            assignedToId: _volunteer!.id,
            status: NeedStatus.inProgress,
          ),
        );
      }

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
    final theme = Theme.of(context);
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'Book Volunteer',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        body: _isLoading
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.primaryColor.withOpacity(0.05),
                      Colors.white,
                    ],
                    stops: const [0.0, 0.3],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading volunteer details...',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.primaryColor.withOpacity(0.05),
                      Colors.white,
                    ],
                    stops: const [0.0, 0.3],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_volunteer != null) ...[
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                                  child: Text(
                                    _volunteer!.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _volunteer!.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _volunteer!.phoneNumber ?? 'No phone number',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
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
                      if (widget.need != null) ...[
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Need Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.need!.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.need!.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: theme.primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Due: ${DateFormat('MMM d, y').format(widget.need!.dueDate)}',
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
                        ),
                      ],
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available Time Slots',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_availableSlots.isEmpty)
                                Center(
                                  child: Text(
                                    'No available time slots',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _availableSlots.keys.map((day) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                              label: Text(
                                                day,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _selectedDay == day
                                                      ? Colors.white
                                                      : theme.primaryColor,
                                                ),
                                              ),
                                              selected: _selectedDay == day,
                                              selectedColor: theme.primaryColor,
                                              backgroundColor: theme.primaryColor.withOpacity(0.1),
                                              onSelected: (selected) {
                                                if (selected) {
                                                  setState(() {
                                                    _selectedDay = day;
                                                    _selectedTimeSlot = null;
                                                  });
                                                }
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (_selectedDay != null)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _availableSlots[_selectedDay]!.map((slot) {
                                          final isSelected = _selectedTimeSlot == slot;
                                          return ChoiceChip(
                                            label: Text(
                                              '${DateFormat('h:mm a').format(slot.startTime)} - ${DateFormat('h:mm a').format(slot.endTime)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isSelected ? Colors.white : theme.primaryColor,
                                              ),
                                            ),
                                            selected: isSelected,
                                            selectedColor: theme.primaryColor,
                                            backgroundColor: theme.primaryColor.withOpacity(0.1),
                                            onSelected: (selected) {
                                              if (selected) {
                                                setState(() {
                                                  _selectedTimeSlot = slot;
                                                });
                                              }
                                            },
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Additional Notes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Enter any additional notes...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: theme.primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: theme.primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _locationController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your location (e.g., address, city)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: theme.primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: theme.primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ElevatedButton(
                          onPressed: _bookAppointment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Book Appointment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}