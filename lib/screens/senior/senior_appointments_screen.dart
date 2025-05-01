import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/review_model.dart';
import 'package:elderly_care_app/widgets/review_dialog.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/screens/senior/appointment_details.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Widget _buildAppointmentCard(Appointment appointment) {
    final theme = Theme.of(context);
    final volunteer = _volunteerProfiles[appointment.volunteerId];
    final isCompleted = appointment.status == AppointmentStatus.completed;
    final isCancelled = appointment.status == AppointmentStatus.cancelled;
    final isUpcoming = appointment.status == AppointmentStatus.scheduled || appointment.status == AppointmentStatus.inProgress;
    final isInProgress = appointment.status == AppointmentStatus.inProgress;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          if (volunteer != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentDetailsScreen(
                  appointment: appointment,
                  volunteer: volunteer,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            volunteer?.name.isNotEmpty == true ? volunteer!.name[0].toUpperCase() : 'V',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            volunteer?.name ?? 'Volunteer',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (volunteer?.phoneNumber != null)
                            Text(
                              volunteer!.phoneNumber!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  _buildStatusChip(appointment.status),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Date',
                    DateFormat('EEEE, MMMM d, y').format(appointment.startTime),
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
                    volunteer?.servingAreas?.first ?? 'Location not specified',
                  ),
                  if (isCompleted) ...[
                    const SizedBox(height: 12),
                    FutureBuilder<Review?>(
                      future: DatabaseService().getAppointmentReview(appointment.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasData && snapshot.data != null) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Review',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    ...List.generate(
                                      5,
                                      (index) => Icon(
                                        Icons.star,
                                        size: 16,
                                        color: index < snapshot.data!.rating
                                            ? Colors.amber
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  snapshot.data!.feedback,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ElevatedButton.icon(
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) => ReviewDialog(
                                appointmentId: appointment.id,
                                volunteerId: appointment.volunteerId,
                                seniorId: appointment.seniorId,
                              ),
                            );
                            
                            if (result == true) {
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.star, size: 16),
                          label: const Text('Rate & Review', style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (isUpcoming) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _cancelAppointment(appointment),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Cancel', style: TextStyle(fontSize: 14)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(AppointmentStatus status) {
    Color color;
    String label;
    IconData icon;
    
    switch (status) {
      case AppointmentStatus.scheduled:
        color = Colors.blue;
        label = 'Scheduled';
        icon = Icons.schedule;
        break;
      case AppointmentStatus.waitingToStart:
        color = Colors.orange;
        label = 'Start Requested';
        icon = Icons.hourglass_empty;
        break;
      case AppointmentStatus.inProgress:
        color = Colors.green;
        label = 'In Progress';
        icon = Icons.play_arrow;
        break;
      case AppointmentStatus.waitingToEnd:
        color = Colors.purple;
        label = 'End Requested';
        icon = Icons.hourglass_full;
        break;
      case AppointmentStatus.completed:
        color = Colors.teal;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        icon = Icons.cancel;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    try {
      final success = await _databaseService.updateAppointmentStatus(
        appointment.id,
        AppointmentStatus.cancelled,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled successfully')),
        );
        setState(() {});
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

  Widget _buildPastAppointmentCard(Appointment appointment) {
    final volunteer = _volunteerProfiles[appointment.volunteerId];
    final isCompleted = appointment.status == AppointmentStatus.completed;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          if (volunteer != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentDetailsScreen(
                  appointment: appointment,
                  volunteer: volunteer,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        volunteer?.name.isNotEmpty == true ? volunteer!.name[0].toUpperCase() : 'V',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          volunteer?.name ?? 'Volunteer',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, y').format(appointment.startTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.teal.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCompleted ? Colors.teal.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: isCompleted ? Colors.teal : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCompleted ? 'Completed' : 'Cancelled',
                          style: TextStyle(
                            color: isCompleted ? Colors.teal : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isCompleted) ...[
                const SizedBox(height: 12),
                FutureBuilder<Review?>(
                  future: DatabaseService().getAppointmentReview(appointment.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasData && snapshot.data != null) {
                      return Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              Icons.star,
                              size: 16,
                              color: index < snapshot.data!.rating
                                  ? Colors.amber
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      );
                    }
                    
                    return ElevatedButton.icon(
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ReviewDialog(
                            appointmentId: appointment.id,
                            volunteerId: appointment.volunteerId,
                            seniorId: appointment.seniorId,
                          ),
                        );
                        
                        if (result == true) {
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.star, size: 16),
                      label: const Text('Rate & Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Appointments',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          elevation: 0,
          backgroundColor: theme.primaryColor,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
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
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.primaryColor.withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<Appointment>>(
                  stream: _databaseService.getSeniorAppointments(widget.seniorId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading appointments',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadAppointments,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    final appointments = snapshot.data ?? [];
                    final actionRequiredAppointments = appointments.where((appointment) => 
                      appointment.status == AppointmentStatus.waitingToStart || 
                      appointment.status == AppointmentStatus.waitingToEnd
                    ).toList();
                    
                    final upcomingAppointments = appointments.where((appointment) => 
                      appointment.status == AppointmentStatus.scheduled || 
                      appointment.status == AppointmentStatus.inProgress
                    ).toList();
                    
                    final pastAppointments = appointments.where((appointment) => 
                      appointment.status == AppointmentStatus.completed || 
                      appointment.status == AppointmentStatus.cancelled
                    ).toList();

                    return TabBarView(
                      children: [
                        // Action Required Tab
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          child: actionRequiredAppointments.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 48,
                                        color: Colors.green[300],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No actions required',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: actionRequiredAppointments.length,
                                  itemBuilder: (context, index) {
                                    return _buildAppointmentCard(
                                        actionRequiredAppointments[index]);
                                  },
                                ),
                        ),
                        // Upcoming Tab
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          child: upcomingAppointments.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.event_note,
                                        size: 48,
                                        color: Colors.blue[300],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No upcoming appointments',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: upcomingAppointments.length,
                                  itemBuilder: (context, index) {
                                    return _buildAppointmentCard(
                                        upcomingAppointments[index]);
                                  },
                                ),
                        ),
                        // Past Tab
                        Container(
                          padding: const EdgeInsets.only(left: 4, right: 4, top: 12, bottom: 36),
                          child: pastAppointments.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.history,
                                        size: 48,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No past appointments',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: pastAppointments.length,
                                  itemBuilder: (context, index) {
                                    return _buildPastAppointmentCard(pastAppointments[index]);
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _loadAppointments,
          backgroundColor: theme.primaryColor,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}