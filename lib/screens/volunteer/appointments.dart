import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/services/database_service.dart';

class AppointmentsScreen extends StatefulWidget {
  final Volunteer volunteer;

  const AppointmentsScreen({Key? key, required this.volunteer}) : super(key: key);

  @override
  _AppointmentsScreenState createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  late TabController _tabController;
  List<Appointment> _upcomingAppointments = [];
  List<Appointment> _pastAppointments = [];
  bool _isLoading = true;
  Map<String, SeniorCitizen> _seniorProfiles = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all appointments for this volunteer
      final appointments = await _databaseService.getVolunteerAppointments(widget.volunteer.id);
      
      // Split into upcoming and past appointments
      setState(() {
        _upcomingAppointments = appointments
            .where((appt) => 
                appt.status == AppointmentStatus.scheduled || 
                appt.status == AppointmentStatus.inProgress)
            .toList();
        _pastAppointments = appointments
            .where((appt) => 
                appt.status == AppointmentStatus.completed || 
                appt.status == AppointmentStatus.cancelled)
            .toList();
      });

      // Load senior profiles for all appointments
      final Set<String> seniorIds = appointments
          .map((appointment) => appointment.seniorId)
          .toSet();

      for (String seniorId in seniorIds) {
        final senior = await _databaseService.getSeniorById(seniorId);
        if (senior != null) {
          setState(() {
            _seniorProfiles[seniorId] = senior;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading appointments: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAppointmentStatus(Appointment appointment, AppointmentStatus newStatus) async {
    try {
      await _databaseService.updateAppointmentStatus(appointment.id, newStatus);
      
      // If completing the appointment, record completion time
      if (newStatus == AppointmentStatus.completed) {
        await _databaseService.completeAppointment(
          appointment.id, 
          DateTime.now(),
        );
        
        // Update volunteer's total hours
        final int durationInHours = appointment.endTime.difference(appointment.startTime).inHours;
        await _databaseService.updateVolunteerHours(
          widget.volunteer.id,
          widget.volunteer.totalHoursVolunteered + durationInHours
        );
      }
      
      // Refresh the appointments list
      await _loadAppointments();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment updated to ${newStatus.toString().split('.').last}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating appointment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentsList(_upcomingAppointments, isUpcoming: true),
                _buildAppointmentsList(_pastAppointments, isUpcoming: false),
              ],
            ),
    );
  }

  Widget _buildAppointmentsList(List<Appointment> appointments, {required bool isUpcoming}) {
    if (appointments.isEmpty) {
      return Center(
        child: Text(
          isUpcoming 
              ? 'No upcoming appointments' 
              : 'No past appointments',
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        final SeniorCitizen? senior = _seniorProfiles[appointment.seniorId];
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Appointment with ${senior?.name ?? 'Senior'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    _buildStatusChip(appointment.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy').format(appointment.startTime),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat.jm().format(appointment.startTime)} - ${DateFormat.jm().format(appointment.endTime)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notes: ${appointment.notes}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isUpcoming) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (appointment.status == AppointmentStatus.scheduled) ...[
                        ElevatedButton(
                          onPressed: () => _updateAppointmentStatus(
                            appointment, 
                            AppointmentStatus.inProgress
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Start'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _updateAppointmentStatus(
                            appointment, 
                            AppointmentStatus.cancelled
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ] else if (appointment.status == AppointmentStatus.inProgress) ...[
                        ElevatedButton(
                          onPressed: () => _updateAppointmentStatus(
                            appointment, 
                            AppointmentStatus.completed
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 249, 249, 249),
                          ),
                          child: const Text('Complete'),
                        ),
                      ],
                    ],
                  ),
                ] else if (appointment.rating != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Rating: ${appointment.rating}/5',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  if (appointment.feedback != null && appointment.feedback!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Feedback: ${appointment.feedback}',
                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(AppointmentStatus status) {
    Color color;
    String label = status.toString().split('.').last;
    
    switch (status) {
      case AppointmentStatus.scheduled:
        color = Colors.blue;
        break;
      case AppointmentStatus.inProgress:
        color = Colors.orange;
        break;
      case AppointmentStatus.completed:
        color = Colors.green;
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        break;
    }
    
    return Chip(
      label: Text(
        label[0].toUpperCase() + label.substring(1),
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }
}