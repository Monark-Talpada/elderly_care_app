import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/review_model.dart';
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
      final appointments = await _databaseService.getVolunteerAppointments(widget.volunteer.id);
      
      setState(() {
        _upcomingAppointments = appointments
            .where((appt) => 
                appt.status == AppointmentStatus.scheduled || 
                appt.status == AppointmentStatus.waitingToStart ||
                appt.status == AppointmentStatus.inProgress ||
                appt.status == AppointmentStatus.waitingToEnd)
            .toList();
        _pastAppointments = appointments
            .where((appt) => 
                appt.status == AppointmentStatus.completed || 
                appt.status == AppointmentStatus.cancelled)
            .toList();
      });

      // Load senior profiles and reviews for all appointments
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

  // Request to start an appointment
  Future<void> _requestStartAppointment(Appointment appointment) async {
    try {
      final success = await _databaseService.requestStartAppointment(appointment.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start request sent to senior for confirmation')),
        );
        await _loadAppointments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send start request')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Request to end an appointment
  Future<void> _requestEndAppointment(Appointment appointment) async {
    try {
      final success = await _databaseService.requestEndAppointment(appointment.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End request sent to senior for confirmation')),
        );
        await _loadAppointments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send end request')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
  try {
    final success = await _databaseService.updateAppointmentStatus(
      appointment.id, 
      AppointmentStatus.cancelled
    );
    if (success) {
      // Release volunteer time slot
      await _databaseService.updateVolunteerTimeSlot(
        appointment.volunteerId,
        DateFormat('yyyy-MM-dd').format(appointment.startTime),
        TimeSlot(
          startTime: appointment.startTime,
          endTime: appointment.endTime,
          isBooked: false,
          bookedById: null,
        ),
        false,
        null,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled')),
      );
      await _loadAppointments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel appointment')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
              : RefreshIndicator(
                  onRefresh: _loadAppointments,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAppointmentsList(
                        _upcomingAppointments, 
                        isUpcoming: true, 
                        maxWidth: constraints.maxWidth
                      ),
                      _buildAppointmentsList(
                        _pastAppointments, 
                        isUpcoming: false, 
                        maxWidth: constraints.maxWidth
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildAppointmentsList(
    List<Appointment> appointments, {
    required bool isUpcoming, 
    required double maxWidth
  }) {
    if (appointments.isEmpty) {
      return Center(
        child: Text(
          isUpcoming 
              ? 'No upcoming appointments' 
              : 'No past appointments',
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        final SeniorCitizen? senior = _seniorProfiles[appointment.seniorId];
        
        return LayoutBuilder(
          builder: (context, constraints) {
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
                        Expanded(
                          child: Text(
                            'Appointment with ${senior?.name ?? 'Senior'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(appointment.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildIconTextRow(
                      icon: Icons.calendar_today, 
                      text: DateFormat('MMM dd, yyyy').format(appointment.startTime)
                    ),
                    const SizedBox(height: 8),
                    _buildIconTextRow(
                      icon: Icons.access_time, 
                      text: '${DateFormat.jm().format(appointment.startTime)} - ${DateFormat.jm().format(appointment.endTime)}'
                    ),
                    
                    // Show actual start time if available
                    if (appointment.actualStartTime != null) ...[
                      const SizedBox(height: 8),
                      _buildIconTextRow(
                        icon: Icons.play_arrow, 
                        text: 'Started: ${DateFormat.jm().format(appointment.actualStartTime!)}'
                      ),
                    ],
                    
                    // Show actual end time if available
                    if (appointment.actualEndTime != null) ...[
                      const SizedBox(height: 8),
                      _buildIconTextRow(
                        icon: Icons.stop, 
                        text: 'Ended: ${DateFormat.jm().format(appointment.actualEndTime!)}'
                      ),
                    ],
                    
                    // Show actual duration if available
                    if (appointment.actualDurationMinutes != null) ...[
                      const SizedBox(height: 8),
                      _buildIconTextRow(
                        icon: Icons.timelapse, 
                        text: 'Duration: ${_formatDuration(appointment.actualDurationMinutes!)}'
                      ),
                    ],
                    
                    if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildIconTextRow(
                        icon: Icons.note, 
                        text: 'Notes: ${appointment.notes}',
                        isMultiline: true,
                      ),
                    ],
                    
                    // Status information
                    if (appointment.status == AppointmentStatus.waitingToStart) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const Text(
                        'Waiting for senior to confirm start',
                        style: TextStyle(
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ] else if (appointment.status == AppointmentStatus.waitingToEnd) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const Text(
                        'Waiting for senior to confirm completion',
                        style: TextStyle(
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    
                    if (isUpcoming) ...[
                      const SizedBox(height: 16),
                      _buildAppointmentActions(appointment, constraints)
                    ] else if (appointment.rating != null) ...[
                      const SizedBox(height: 12),
                      _buildRatingAndFeedback(appointment)
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to format duration in minutes to hours and minutes
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

  Widget _buildIconTextRow({
    required IconData icon, 
    required String text, 
    bool isMultiline = false
  }) {
    return Row(
      crossAxisAlignment: isMultiline 
          ? CrossAxisAlignment.start 
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
            maxLines: isMultiline ? 3 : 1,
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentActions(Appointment appointment, BoxConstraints constraints) {
    // Different actions based on appointment status
    switch (appointment.status) {
      case AppointmentStatus.scheduled:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton(
              text: 'Start',
              color: Colors.green,
              onPressed: () => _requestStartAppointment(appointment),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              text: 'Cancel',
              color: Colors.red,
              onPressed: () => _cancelAppointment(appointment),
            ),
          ],
        );
        
      case AppointmentStatus.waitingToStart:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton(
              text: 'Cancel Request',
              color: Colors.orange,
              // Revert back to scheduled
              onPressed: () async {
                await _databaseService.updateAppointmentStatus(
                  appointment.id, 
                  AppointmentStatus.scheduled
                );
                _loadAppointments();
              },
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              text: 'Cancel Appointment',
              color: Colors.red,
              onPressed: () => _cancelAppointment(appointment),
            ),
          ],
        );
        
      case AppointmentStatus.inProgress:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton(
              text: 'End Appointment',
              color: Colors.blue,
              onPressed: () => _requestEndAppointment(appointment),
            ),
          ],
        );
        
      case AppointmentStatus.waitingToEnd:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Awaiting senior confirmation',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        );
        
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(100, 40),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRatingAndFeedback(Appointment appointment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            style: const TextStyle(
              fontSize: 16, 
              fontStyle: FontStyle.italic
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(AppointmentStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case AppointmentStatus.scheduled:
        color = Colors.blue;
        label = 'Scheduled';
        break;
      case AppointmentStatus.waitingToStart:
        color = Colors.orange;
        label = 'Start Requested';
        break;
      case AppointmentStatus.inProgress:
        color = Colors.green;
        label = 'In Progress';
        break;
      case AppointmentStatus.waitingToEnd:
        color = Colors.purple;
        label = 'End Requested';
        break;
      case AppointmentStatus.completed:
        color = Colors.teal;
        label = 'Completed';
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
    }
    
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final isCompleted = appointment.status == AppointmentStatus.completed;
    final isCancelled = appointment.status == AppointmentStatus.cancelled;
    final isUpcoming = appointment.status == AppointmentStatus.scheduled || 
                      appointment.status == AppointmentStatus.waitingToStart || 
                      appointment.status == AppointmentStatus.inProgress || 
                      appointment.status == AppointmentStatus.waitingToEnd;
    final isInProgress = appointment.status == AppointmentStatus.inProgress;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Appointment with ${_seniorProfiles[appointment.seniorId]?.name ?? 'Senior'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(appointment.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              DateFormat('MMM dd, yyyy').format(appointment.startTime),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              'Time',
              '${DateFormat.jm().format(appointment.startTime)} - ${DateFormat.jm().format(appointment.endTime)}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.location_on,
              'Location',
              _seniorProfiles[appointment.seniorId]?.lastKnownLocation != null
                  ? '${_seniorProfiles[appointment.seniorId]?.lastKnownLocation?.latitude.toStringAsFixed(6)}, ${_seniorProfiles[appointment.seniorId]?.lastKnownLocation?.longitude.toStringAsFixed(6)}'
                  : 'Location not specified',
            ),
            const SizedBox(height: 16),
            if (isCompleted)
              FutureBuilder<Review?>(
                future: _databaseService.getAppointmentReview(appointment.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasData && snapshot.data != null) {
                    final review = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Senior\'s Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (index) => Icon(
                                Icons.star,
                                size: 20,
                                color: index < review.rating
                                    ? Colors.amber
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM dd, yyyy').format(review.createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          review.feedback,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    );
                  }
                  
                  return const Text(
                    'No review yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                },
              ),
            if (isInProgress)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _requestEndAppointment(appointment),
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        Text(value),
      ],
    );
  }
}