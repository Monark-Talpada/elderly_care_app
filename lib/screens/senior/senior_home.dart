import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/utils/navigation_utils.dart';
import 'package:elderly_care_app/screens/senior/emergency_button.dart';
import 'package:elderly_care_app/screens/senior/senior_appointments_screen.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class SeniorHomeScreen extends StatefulWidget {
  const SeniorHomeScreen({Key? key}) : super(key: key);

  @override
  _SeniorHomeScreenState createState() => _SeniorHomeScreenState();
}

class _SeniorHomeScreenState extends State<SeniorHomeScreen> {
  late AuthService _authService;
  late DatabaseService _databaseService;
  bool _isLoading = true;
  SeniorCitizen? _senior;
  List<DailyNeed> _upcomingNeeds = [];
  List<FamilyMember> _connectedFamilyMembers = [];

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadSeniorData();
  }

  Future<void> _loadSeniorData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = _authService.currentUser;
      if (user != null) {
        final senior = await _databaseService.getSeniorById(user.id);

        if (senior == null) {
          print('Senior not found for ID: ${user.id}');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        print('Loading needs for senior ID: ${senior.id}');
        final needs = await _databaseService.getSeniorNeeds(senior.id);
        print('Loaded ${needs.length} needs');

        needs.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final upcomingNeeds = needs
            .where((need) =>
                need.status != NeedStatus.completed &&
                need.status != NeedStatus.cancelled)
            .toList();

        final familyMembers =
            await _databaseService.getConnectedFamilyMembers(senior.id);

        if (mounted) {
          setState(() {
            _senior = senior;
            _upcomingNeeds = upcomingNeeds;
            _connectedFamilyMembers = familyMembers;
            _isLoading = false;
          });
        }
      } else {
        print('No current user found');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading senior data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  

  void _navigateToEmergencyButton() {
    Navigator.pushNamed(context, '/emergency_button').then((_) {
      // Refresh data when returning from the emergency button screen
      _loadSeniorData();
    });
  }

   void _editSeniorName() async {
    final TextEditingController _controller =
        TextEditingController(text: _senior!.name);

    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: "Enter new name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.trim().isNotEmpty) {
      setState(() {
        _senior = _senior!.copyWith(name: newName.trim());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_senior == null) {
      return Scaffold(
        body: Center(
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
                'Unable to load profile. Please try again later.',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadSeniorData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Senior Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/senior/profile');
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSeniorData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${_senior!.name}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You have ${_connectedFamilyMembers.length} connected family member${_connectedFamilyMembers.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/senior/family_connections')
                              .then((_) => _loadSeniorData());
                        },
                        icon: const Icon(Icons.family_restroom),
                        label: const Text('Manage Family Connections'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Emergency button section
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: _senior!.emergencyModeActive ? Colors.red.shade700 : Colors.red,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _navigateToEmergencyButton,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _senior!.emergencyModeActive
                                ? Icons.cancel_outlined
                                : Icons.emergency,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _senior!.emergencyModeActive ? 'CANCEL EMERGENCY' : 'EMERGENCY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Daily needs section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: theme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Upcoming Needs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/senior/daily_needs').then((_) {
                        _loadSeniorData();
                      });
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _upcomingNeeds.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'No upcoming needs at the moment',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _upcomingNeeds.length > 3 ? 3 : _upcomingNeeds.length,
                      itemBuilder: (context, index) {
                        final need = _upcomingNeeds[index];
                        return _buildNeedCard(need);
                      },
                    ),
              
              const SizedBox(height: 32),
              
              // Quick actions section
              Row(
                children: [
                  Icon(
                    Icons.dashboard,
                    color: theme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    'Add Need',
                    Icons.add_task,
                    Colors.green,
                    () => Navigator.pushNamed(context, '/senior/add_need'),
                  ),
                  _buildActionCard(
                    'Book Volunteer',
                    Icons.people,
                    Colors.blue,
                    () => Navigator.pushNamed(context, '/senior/select_volunteer'),
                  ),
                  _buildActionCard(
                    'My Appointments',
                    Icons.calendar_month,
                    Colors.amber,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SeniorAppointmentsScreen(
                          seniorId: _senior!.id,
                        ),
                      ),
                    ).then((_) => _loadSeniorData()),
                  ),
                  _buildActionCard(
                    'Emergency Contacts',
                    Icons.emergency,
                    Colors.red,
                    () => Navigator.pushNamed(context, '/senior/emergency_contacts'),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Connected family section
              if (_connectedFamilyMembers.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.family_restroom,
                      color: theme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Connected Family',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _connectedFamilyMembers.length > 5
                        ? 5
                        : _connectedFamilyMembers.length,
                    itemBuilder: (context, index) {
                      final member = _connectedFamilyMembers[index];
                      return _buildFamilyMemberCard(member);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeedCard(DailyNeed need) {
    final IconData icon;
    final Color color;

    switch (need.type) {
      case NeedType.medication:
        icon = Icons.medication;
        color = Colors.blue;
        break;
      case NeedType.appointment:
        icon = Icons.calendar_today;
        color = Colors.purple;
        break;
      case NeedType.grocery:
        icon = Icons.shopping_basket;
        color = Colors.green;
        break;
      case NeedType.other:
        icon = Icons.more_horiz;
        color = Colors.orange;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/senior/need_details',
            arguments: need,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      need.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      need.description.length > 30
                          ? '${need.description.substring(0, 30)}...'
                          : need.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, h:mm a').format(need.dueDate),
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
              _getStatusChip(need.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getStatusChip(NeedStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case NeedStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      case NeedStatus.inProgress:
        color = Colors.blue;
        label = 'In Progress';
        icon = Icons.refresh;
        break;
      case NeedStatus.completed:
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case NeedStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyMemberCard(FamilyMember member) {
    return Card(
      margin: const EdgeInsets.only(right: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (member.relationship != null)
                Text(
                  member.relationship!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      NavigationUtils.signOut(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }
}