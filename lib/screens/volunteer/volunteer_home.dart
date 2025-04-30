import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/screens/volunteer/availability.dart';
import 'package:elderly_care_app/screens/volunteer/appointments.dart';
import 'package:elderly_care_app/utils/navigation_utils.dart';

class VolunteerHomeScreen extends StatefulWidget {
  final String volunteerId;

  const VolunteerHomeScreen({Key? key, required this.volunteerId}) : super(key: key);

  @override
  _VolunteerHomeScreenState createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  
  late Future<Volunteer?> _volunteerFuture;
  List<Appointment> _upcomingAppointments = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Widget _buildStatusChip(AppointmentStatus status) {
    Color chipColor;
    String chipText;

    switch (status) {
      case AppointmentStatus.scheduled:
        chipColor = Colors.blue.shade100;
        chipText = 'Scheduled';
        break;
      case AppointmentStatus.inProgress:
        chipColor = Colors.orange.shade100;
        chipText = 'In Progress';
        break;
      case AppointmentStatus.completed:
        chipColor = Colors.green.shade100;
        chipText = 'Completed';
        break;
      case AppointmentStatus.cancelled:
        chipColor = Colors.red.shade100;
        chipText = 'Cancelled';
        break;
      default:
        chipColor = Colors.grey.shade100;
        chipText = 'Unknown';
    }

    return Chip(
      label: Text(
        chipText, 
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _volunteerFuture = _databaseService.getVolunteer(widget.volunteerId);
    });
    
    try {
      final volunteer = await _volunteerFuture;
      if (volunteer != null) {
        final appointments = await _databaseService.getVolunteerAppointments(volunteer.id);
        
        setState(() {
         _upcomingAppointments = appointments
            .where((appt) => 
                appt.status == AppointmentStatus.scheduled || 
                appt.status == AppointmentStatus.inProgress)
            .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      NavigationUtils.signOut(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Volunteer?>(
      future: _volunteerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        
        final volunteer = snapshot.data;
        if (volunteer == null) {
          return const Scaffold(
            body: Center(child: Text('Volunteer not found')),
          );
        }
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final isWide = constraints.maxWidth >= 1200;

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  'Volunteer Dashboard', 
                  style: TextStyle(
                    fontSize: isNarrow ? 18 : 22,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: CircleAvatar(
                      radius: isNarrow ? 12 : 14,
                      child: Icon(Icons.person, size: isNarrow ? 14 : 16),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/volunteer_profile',
                        arguments: volunteer,
                      );
                    },
                    tooltip: 'Update Profile',
                  ),
                  IconButton(
                    icon: const Icon(Icons.exit_to_app),
                    onPressed: _signOut,
                  ),
                ],
              ),
              body: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.all(isNarrow ? 8.0 : 16.0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildVolunteerHeader(volunteer, isNarrow),
                            SizedBox(height: constraints.maxHeight * 0.02),
                            _buildUpcomingAppointmentsSection(constraints, isNarrow),
                            SizedBox(height: constraints.maxHeight * 0.02),
                            _buildStatisticsSection(volunteer, constraints, isNarrow),
                            SizedBox(height: constraints.maxHeight * 0.02),
                            _buildActionCards(volunteer, constraints, isNarrow),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildVolunteerHeader(Volunteer volunteer, bool isNarrow) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          elevation: 4,
          child: Padding(
            padding: EdgeInsets.all(isNarrow ? 8.0 : 16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: isNarrow ? constraints.maxWidth * 0.08 : constraints.maxWidth * 0.1,
                  backgroundImage: volunteer.photoUrl != null 
                      ? NetworkImage(volunteer.photoUrl!)
                      : null,
                  child: volunteer.photoUrl == null
                      ? Icon(Icons.person, size: isNarrow ? 30 : 40)
                      : null,
                ),
                SizedBox(width: constraints.maxWidth * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          volunteer.name,
                          style: TextStyle(
                            fontSize: isNarrow ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                     
                      if (volunteer.rating != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: isNarrow ? 16 : 20),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${volunteer.rating!.toStringAsFixed(1)} (${volunteer.ratingCount ?? 0} reviews)',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: isNarrow ? 12 : 14,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
      },
    );
  }
  
  Widget _buildUpcomingAppointmentsSection(BoxConstraints constraints, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Appointments',
              style: TextStyle(
                fontSize: isNarrow ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () async {
                final volunteer = await _volunteerFuture;
                if (volunteer != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentsScreen(volunteer: volunteer),
                    ),
                  );
                }
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_upcomingAppointments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No upcoming appointments',
                  style: TextStyle(fontSize: isNarrow ? 14 : 16),
                ),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * 0.3,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _upcomingAppointments.length,
              itemBuilder: (context, index) {
                final appointment = _upcomingAppointments[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      DateFormat('MMM dd, yyyy').format(appointment.startTime),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${DateFormat.jm().format(appointment.startTime)} - ${DateFormat.jm().format(appointment.endTime)}',
                    ),
                    trailing: _buildStatusChip(appointment.status),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
  
  Widget _buildStatisticsSection(Volunteer volunteer, BoxConstraints constraints, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Impact',
          style: TextStyle(
            fontSize: isNarrow ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, boxConstraints) {
            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Hours Volunteered',
                    value: volunteer.totalHoursVolunteered.toString(),
                    icon: Icons.timer,
                    color: Colors.blue,
                    maxWidth: boxConstraints.maxWidth * 0.5,
                    isNarrow: isNarrow,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Areas Served',
                    value: volunteer.servingAreas.length.toString(),
                    icon: Icons.location_on,
                    color: Colors.orange,
                    maxWidth: boxConstraints.maxWidth * 0.5,
                    isNarrow: isNarrow,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double maxWidth,
    required bool isNarrow,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(isNarrow ? 8.0 : 16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: isNarrow ? 24 : 32),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isNarrow ? 20 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isNarrow ? 12 : 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionCards(Volunteer volunteer, BoxConstraints constraints, bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: isNarrow ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, boxConstraints) {
            return Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: 'Update Availability',
                    icon: Icons.calendar_today,
                    color: Colors.green,
                    maxWidth: boxConstraints.maxWidth * 0.5,
                    isNarrow: isNarrow,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AvailabilityScreen(volunteer: volunteer),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    title: 'Manage Appointments',
                    icon: Icons.schedule,
                    color: Colors.purple,
                    maxWidth: boxConstraints.maxWidth * 0.5,
                    isNarrow: isNarrow,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppointmentsScreen(volunteer: volunteer),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required double maxWidth,
    required bool isNarrow,
    required VoidCallback onTap,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isNarrow ? 8.0 : 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: isNarrow ? 24 : 32),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isNarrow ? 14 : 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}