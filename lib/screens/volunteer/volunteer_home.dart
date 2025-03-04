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
                  (appt.status == AppointmentStatus.scheduled || 
                   appt.status == AppointmentStatus.inProgress) &&
                  appt.startTime.isAfter(DateTime.now()))
              .take(3)
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
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Volunteer Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: _signOut,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVolunteerHeader(volunteer),
                    const SizedBox(height: 24),
                    _buildUpcomingAppointmentsSection(),
                    const SizedBox(height: 24),
                    _buildStatisticsSection(volunteer),
                    const SizedBox(height: 24),
                    _buildActionCards(volunteer),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildVolunteerHeader(Volunteer volunteer) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: volunteer.photoUrl != null 
                  ? NetworkImage(volunteer.photoUrl!)
                  : null,
              child: volunteer.photoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    volunteer.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        color: volunteer.isVerified ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        volunteer.isVerified ? 'Verified Volunteer' : 'Pending Verification',
                        style: TextStyle(
                          color: volunteer.isVerified ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (volunteer.rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${volunteer.rating!.toStringAsFixed(1)} (${volunteer.ratingCount ?? 0} reviews)',
                          style: const TextStyle(color: Colors.black54),
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
  
  Widget _buildUpcomingAppointmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Appointments',
              style: TextStyle(
                fontSize: 20,
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
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No upcoming appointments',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          )
        else
          Column(
            children: _upcomingAppointments.map((appointment) {
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
            }).toList(),
          ),
      ],
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
  
  Widget _buildStatisticsSection(Volunteer volunteer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Impact',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Hours Volunteered',
                value: volunteer.totalHoursVolunteered.toString(),
                icon: Icons.timer,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Areas Served',
                value: volunteer.servingAreas.length.toString(),
                icon: Icons.location_on,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionCards(Volunteer volunteer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Update Availability',
                icon: Icons.calendar_today,
                color: Colors.green,
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
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Update Profile',
                icon: Icons.person,
                color: Colors.blue,
                onTap: () {
                  // Navigate to profile edit screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile update coming soon')),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                title: 'Update Skills',
                icon: Icons.psychology,
                color: Colors.amber,
                onTap: () {
                  // Navigate to skills update screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Skills update coming soon')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}