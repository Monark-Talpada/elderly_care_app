import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/services/database_service.dart';

class SeniorAppointmentsScreen extends StatefulWidget {
  final String seniorId;
  const SeniorAppointmentsScreen({Key? key, required this.seniorId}) : super(key: key);

  @override
  State<SeniorAppointmentsScreen> createState() => _SeniorAppointmentsScreenState();
}

class _SeniorAppointmentsScreenState extends State<SeniorAppointmentsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Appointment> _appointments = [];
  Map<String, Volunteer> _volunteerProfiles = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
  setState(() {
    _isLoading = true;
  });
  _databaseService.getSeniorAppointments(widget.seniorId).listen(
    (appointments) {
      print('Received ${appointments.length} appointments: ${appointments.map((a) => a.status).toList()}');
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
      for (var appointment in appointments) {
        _loadVolunteerProfile(appointment.volunteerId);
      }
    },
    onError: (error) {
      print('Stream error: $error');
      setState(() {
        _isLoading = false;
      });
    },
  );
}

  Future<void> _loadVolunteerProfile(String volunteerId) async {
    if (!_volunteerProfiles.containsKey(volunteerId)) {
      final volunteer = await _databaseService.getVolunteer(volunteerId);
      if (volunteer != null) {
        setState(() {
          _volunteerProfiles[volunteerId] = volunteer;
        });
      }
    }
  }

  // Senior confirms start of appointment
  Future<void> _confirmStartAppointment(Appointment appointment) async {
    bool success = await _databaseService.confirmAppointmentStart(appointment.id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment started successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start appointment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Senior confirms end of appointment
  Future<void> _confirmEndAppointment(Appointment appointment) async {
    bool success = await _databaseService.confirmAppointmentEnd(appointment.id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to complete appointment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show confirmation dialog for appointment actions
  Future<void> _showConfirmationDialog(
      BuildContext context, String title, String message, Function onConfirm) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  // Display information about the volunteer
  Widget _buildVolunteerInfo(String volunteerId) {
    if (_volunteerProfiles.containsKey(volunteerId)) {
      Volunteer volunteer = _volunteerProfiles[volunteerId]!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Volunteer: ${volunteer.name}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (volunteer.phoneNumber != null)
            Text('Phone: ${volunteer.phoneNumber}'),
        ],
      );
    } else {
      return const Text('Loading volunteer information...');
    }
  }

  // Get the appropriate action button based on appointment status
  Widget _buildActionButton(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.waitingToStart:
        return ElevatedButton(
          onPressed: () {
            _showConfirmationDialog(
              context,
              'Start Appointment',
              'Do you want to confirm the start of this appointment?',
              () => _confirmStartAppointment(appointment),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Confirm Start'),
        );
      case AppointmentStatus.waitingToEnd:
        return ElevatedButton(
          onPressed: () {
            _showConfirmationDialog(
              context,
              'End Appointment',
              'Do you want to confirm the end of this appointment?',
              () => _confirmEndAppointment(appointment),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('Confirm End'),
        );
      case AppointmentStatus.inProgress:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'In Progress',
            style: TextStyle(color: Colors.blue),
          ),
        );
      case AppointmentStatus.completed:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Completed',
            style: TextStyle(color: Colors.green),
          ),
        );
      case AppointmentStatus.cancelled:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Cancelled',
            style: TextStyle(color: Colors.red),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Scheduled',
            style: TextStyle(color: Colors.grey),
          ),
        );
    }
  }

  // Format appointment time range
  String _formatTimeRange(DateTime start, DateTime end) {
    final DateFormat dateFormat = DateFormat('MMM d, yyyy');
    final DateFormat timeFormat = DateFormat('h:mm a');
    
    if (start.day == end.day && start.month == end.month && start.year == end.year) {
      // Same day
      return '${dateFormat.format(start)} from ${timeFormat.format(start)} to ${timeFormat.format(end)}';
    } else {
      // Different days
      return '${dateFormat.format(start)} ${timeFormat.format(start)} to ${dateFormat.format(end)} ${timeFormat.format(end)}';
    }
  }

  // Build appointment card
  Widget _buildAppointmentCard(Appointment appointment) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appointment time and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _formatTimeRange(appointment.startTime, appointment.endTime),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusBadge(appointment.status),
              ],
            ),
            const SizedBox(height: 8),
            
            // Volunteer information
            _buildVolunteerInfo(appointment.volunteerId),
            
            // Notes if available
            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${appointment.notes}'),
            ],
            
            // Action buttons
            const SizedBox(height: 16),
            _buildActionButton(appointment),
            
            // Show actual times if available
            if (appointment.actualStartTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Started: ${DateFormat('MMM d, h:mm a').format(appointment.actualStartTime!)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            if (appointment.actualEndTime != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ended: ${DateFormat('MMM d, h:mm a').format(appointment.actualEndTime!)}',
                style: const TextStyle(color: Colors.grey),
              ),
              if (appointment.actualDurationMinutes != null) ...[
                Text(
                  'Duration: ${_formatDuration(appointment.actualDurationMinutes!)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Format duration from minutes to hours and minutes
  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours hour${hours > 1 ? 's' : ''}';
      } else {
        return '$hours hour${hours > 1 ? 's' : ''} $remainingMinutes minute${remainingMinutes > 1 ? 's' : ''}';
      }
    }
  }

  // Build status badge
  Widget _buildStatusBadge(AppointmentStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case AppointmentStatus.scheduled:
        color = Colors.grey;
        label = 'Scheduled';
        break;
      case AppointmentStatus.waitingToStart:
        color = Colors.amber;
        label = 'Start Requested';
        break;
      case AppointmentStatus.inProgress:
        color = Colors.blue;
        label = 'In Progress';
        break;
      case AppointmentStatus.waitingToEnd:
        color = Colors.orange;
        label = 'End Requested';
        break;
      case AppointmentStatus.completed:
        color = Colors.green;
        label = 'Completed';
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Group appointments by date
  Map<String, List<Appointment>> _groupAppointmentsByDate() {
    Map<String, List<Appointment>> grouped = {};
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    
    for (var appointment in _appointments) {
      final String dateKey = formatter.format(appointment.startTime);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(appointment);
    }
    
    return grouped;
  }

  // Filter appointments by status
  List<Appointment> _getActionRequiredAppointments() {
    return _appointments.where((appointment) => 
      appointment.status == AppointmentStatus.waitingToStart || 
      appointment.status == AppointmentStatus.waitingToEnd
    ).toList();
  }

  // Filter appointments by status for upcoming
  List<Appointment> _getUpcomingAppointments() {
    return _appointments.where((appointment) => 
      appointment.status == AppointmentStatus.scheduled || 
      appointment.status == AppointmentStatus.inProgress
    ).toList();
  }

  // Filter appointments by status for past
  List<Appointment> _getPastAppointments() {
    return _appointments.where((appointment) => 
      appointment.status == AppointmentStatus.completed || 
      appointment.status == AppointmentStatus.cancelled
    ).toList();
  }

  @override
Widget build(BuildContext context) {
  return DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        bottom: TabBar(
          tabs: [
            Tab(
              text: 'Action Required',
              icon: StreamBuilder<List<Appointment>>(
                stream: _databaseService.getSeniorAppointments(widget.seniorId),
                builder: (context, snapshot) {
                  final actionRequiredAppointments = snapshot.hasData
                      ? snapshot.data!
                          .where((appointment) =>
                              appointment.status ==
                                  AppointmentStatus.waitingToStart ||
                              appointment.status ==
                                  AppointmentStatus.waitingToEnd)
                          .toList()
                      : [];
                  return Badge(
                    isLabelVisible: actionRequiredAppointments.isNotEmpty,
                    label: Text('${actionRequiredAppointments.length}'),
                    child: const Icon(Icons.notification_important),
                  );
                },
              ),
            ),
            const Tab(text: 'Upcoming', icon: Icon(Icons.event)),
            const Tab(text: 'Past', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: StreamBuilder<List<Appointment>>(
        stream: _databaseService.getSeniorAppointments(widget.seniorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final appointments = snapshot.data ?? [];
          final actionRequiredAppointments = _getActionRequiredAppointments();
          final upcomingAppointments = _getUpcomingAppointments();
          final pastAppointments = _getPastAppointments();

          return TabBarView(
            children: [
              // Action Required Tab
              actionRequiredAppointments.isEmpty
                  ? const Center(child: Text('No actions required'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: actionRequiredAppointments.length,
                      itemBuilder: (context, index) {
                        return _buildAppointmentCard(
                            actionRequiredAppointments[index]);
                      },
                    ),
              // Upcoming Tab
              upcomingAppointments.isEmpty
                  ? const Center(child: Text('No upcoming appointments'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: upcomingAppointments.length,
                      itemBuilder: (context, index) {
                        return _buildAppointmentCard(
                            upcomingAppointments[index]);
                      },
                    ),
              // Past Tab
              pastAppointments.isEmpty
                  ? const Center(child: Text('No past appointments'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pastAppointments.length,
                      itemBuilder: (context, index) {
                        return _buildAppointmentCard(pastAppointments[index]);
                      },
                    ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.refresh),
        onPressed: _loadAppointments,
      ),
    ),
  );
}
}