import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:elderly_care_app/models/user_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/screens/senior/book_volunteer.dart';
import 'package:flutter/services.dart';

class SelectVolunteerScreen extends StatefulWidget {
  final DailyNeed? need;

  const SelectVolunteerScreen({
    Key? key,
    this.need,
  }) : super(key: key);

  @override
  _SelectVolunteerScreenState createState() => _SelectVolunteerScreenState();
}

class _SelectVolunteerScreenState extends State<SelectVolunteerScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  TimeSlot? _selectedTimeSlot;
  List<Volunteer> _availableVolunteers = [];
  bool _isLoading = true;
  SeniorCitizen? _senior;

  @override
  void initState() {
    super.initState();
    _loadSeniorData();
  }

  Future<void> _loadSeniorData() async {
    final user = _authService.currentUser;
    if (user != null && user.userType == UserType.senior) {
      _senior = await _databaseService.getSeniorById(user.id);
      if (_senior != null && _senior!.lastKnownLocation != null) {
        _locationController.text = '${_senior!.lastKnownLocation!.latitude.toStringAsFixed(6)}, ${_senior!.lastKnownLocation!.longitude.toStringAsFixed(6)}';
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = null;
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
        _selectedTimeSlot = null;
        _availableVolunteers = [];
      });
    }
  }

  Future<void> _findAvailableVolunteers() async {
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
      // Create a time slot for the selected date and time
      final timeSlot = TimeSlot(
        startTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
        endTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour + 1,
          _selectedTime.minute,
        ),
      );

      // Find volunteers available in the senior's location
      final volunteers = await _databaseService.findAvailableVolunteers(
        seniorLocation: _locationController.text.trim(),
        timeSlot: timeSlot,
      );

      setState(() {
        _availableVolunteers = volunteers;
        _selectedTimeSlot = timeSlot;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding volunteers: $e')),
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
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Your Location',
                hintText: 'Enter your address or city',
                border: OutlineInputBorder(),
              ),
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
            ElevatedButton(
              onPressed: _findAvailableVolunteers,
              child: const Text('Find Available Volunteers'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_availableVolunteers.isEmpty && _selectedTimeSlot != null)
              const Center(
                child: Text(
                  'No volunteers available at this time and location',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _availableVolunteers.length,
                  itemBuilder: (context, index) {
                    final volunteer = _availableVolunteers[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: volunteer.photoUrl != null
                              ? NetworkImage(volunteer.photoUrl!)
                              : null,
                          child: volunteer.photoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(volunteer.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Serving Areas: ${volunteer.servingAreas.join(', ')}'),
                            if (volunteer.rating != null)
                              Text('Rating: ${volunteer.rating!.toStringAsFixed(1)}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookVolunteerScreen(
                                  volunteerId: volunteer.id,
                                  need: widget.need,
                                ),
                              ),
                            );
                          },
                          child: const Text('Book'),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}