import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';

class SelectVolunteerScreen extends StatefulWidget {
  const SelectVolunteerScreen({Key? key}) : super(key: key);

  @override
  _SelectVolunteerScreenState createState() => _SelectVolunteerScreenState();
}

class _SelectVolunteerScreenState extends State<SelectVolunteerScreen> {
  late DatabaseService _databaseService;
  late AuthService _authService;
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedDay = '';
  TimeSlot? _selectedTimeSlot;
  
  List<Volunteer> _availableVolunteers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _appointmentDescription = '';
  
  final TextEditingController _descriptionController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _updateSelectedDay();
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
  
  void _updateSelectedDay() {
    // Convert selected date to day of week (e.g., 'monday')
    final DateFormat formatter = DateFormat('EEEE');
    _selectedDay = formatter.format(_selectedDate).toLowerCase();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateSelectedDay();
        // Reset available volunteers when date changes
        _availableVolunteers = [];
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
        // Reset available volunteers when time changes
        _availableVolunteers = [];
      });
    }
  }
  
  Future<void> _searchAvailableVolunteers() async {
    // Combine date and time
    final DateTime startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    
    // Create an end time 1 hour later
    final DateTime endDateTime = startDateTime.add(const Duration(hours: 1));
    
    // Create a TimeSlot object
    final TimeSlot timeSlot = TimeSlot(
      startTime: startDateTime,
      endTime: endDateTime,
      isBooked: false,
    );
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedTimeSlot = timeSlot;
    });
    
    try {
      // Format the date as YYYY-MM-DD
      final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // Get available volunteers for the selected date and time slot
      final volunteers = await _databaseService.getAvailableVolunteers(
        formattedDate,
        timeSlot,
      );
      
      setState(() {
        _availableVolunteers = volunteers;
        _isLoading = false;
        
        if (volunteers.isEmpty) {
          _errorMessage = 'No volunteers available for the selected time.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading volunteers: ${e.toString()}';
      });
    }
  }
  
  Future<void> _bookVolunteer(Volunteer volunteer) async {
    final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }
    
    if (_selectedTimeSlot == null) {
      return;
    }
    
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Print debugging info
      print('Booking appointment with:');
      print('Senior ID: ${user.id}');
      print('Volunteer ID: ${volunteer.id}');
      print('Date: $_selectedDate');
      print('Time: $_selectedTime');
      print('Description: ${_descriptionController.text.trim()}');
      
      // Combine date and time for appointment
      final DateTime appointmentDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      // Book the appointment
      final String? appointmentId = await _databaseService.bookAppointment(
        seniorId: user.id,
        volunteerId: volunteer.id,
        appointmentDate: appointmentDateTime,
        description: _descriptionController.text.trim(),
      );
      
      print('Appointment booking result: ${appointmentId != null ? "Success" : "Failed"}');
      
      // Update volunteer's time slot to booked
      bool success = await _databaseService.updateVolunteerTimeSlot(
        volunteer.id,
        formattedDate,
        _selectedTimeSlot!,
        true, // isBooked
        user.id, // bookedById
      );
      
      print('Time slot update result: ${success ? "Success" : "Failed"}');
      
      setState(() {
        _isLoading = false;
      });

      if (appointmentId == null) {
        print('Failed to create appointment record');
      }
    
      if (!success) {
        print('Failed to update volunteer time slot');
      }
      
      if (appointmentId != null && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked successfully!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to book appointment')),
        );
      }
    } catch (e) {
      print('Booking exception details: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}, message: ${e.message}');
      }
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking appointment: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Volunteer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Date and Time',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(context),
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Appointment Description',
                hintText: 'Enter details about what you need help with',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _searchAvailableVolunteers,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Find Available Volunteers'),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_availableVolunteers.isNotEmpty) ...[
              Text(
                'Available Volunteers',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _availableVolunteers.length,
                  itemBuilder: (context, index) {
                    final volunteer = _availableVolunteers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: volunteer.photoUrl != null
                              ? NetworkImage(volunteer.photoUrl!)
                              : null,
                          child: volunteer.photoUrl == null
                              ? Text(volunteer.name.substring(0, 1).toUpperCase())
                              : null,
                        ),
                        title: Text(volunteer.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Experience: ${volunteer.experienceYears} years'),
                            // In the ListTile widget in build() method
                            Text('Rating: ${volunteer.rating?.toStringAsFixed(1) ?? 'N/A'} ⭐'),   ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _bookVolunteer(volunteer),
                          child: const Text('Book'),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}