import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/utils/navigation_utils.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadSeniorData();
  }

  Future<void> _loadSeniorData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final senior = await _databaseService.getSeniorById(user.id);
        final needs = await _databaseService.getSeniorNeeds(user.id);
        
        // Sort needs by due date
        needs.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        
        // Filter for upcoming needs (not completed or cancelled)
        final upcomingNeeds = needs.where((need) => 
            need.status != NeedStatus.completed && 
            need.status != NeedStatus.cancelled).toList();
        
        if (mounted) {
          setState(() {
            _senior = senior;
            _upcomingNeeds = upcomingNeeds;
            _isLoading = false;
          });
        }
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

  Future<void> _toggleEmergencyMode() async {
    if (_senior == null) return;
    
    try {
      final updatedSenior = _senior!.copyWith(
        emergencyModeActive: !_senior!.emergencyModeActive
      );
      
      await _databaseService.updateSenior(updatedSenior);
      
      setState(() {
        _senior = updatedSenior;
      });
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_senior!.emergencyModeActive 
              ? 'Emergency mode activated! Help is on the way.' 
              : 'Emergency mode deactivated.'),
          backgroundColor: _senior!.emergencyModeActive ? Colors.red : Colors.green,
        ),
      );
    } catch (e) {
      print('Error toggling emergency mode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update emergency status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_senior == null) {
      return const Scaffold(
        body: Center(
          child: Text('Unable to load profile. Please try again later.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Senior Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/senior/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
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
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              _buildEmergencyButton(),
              const SizedBox(height: 24),
              _buildDailyNeedsSection(),
              const SizedBox(height: 24),
              _buildQuickActionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: _senior!.photoUrl != null 
                  ? NetworkImage(_senior!.photoUrl!)
                  : null,
              child: _senior!.photoUrl == null
                  ? Text(_senior!.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 32))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${_senior!.name}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How are you feeling today?',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connected Family Members: ${_senior!.connectedFamilyIds.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return InkWell(
      onTap: _toggleEmergencyMode,
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: _senior!.emergencyModeActive ? Colors.red.shade700 : Colors.red,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _senior!.emergencyModeActive ? 'CANCEL EMERGENCY' : 'EMERGENCY',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyNeedsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Needs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/senior/daily_needs');
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _upcomingNeeds.isEmpty
            ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No upcoming needs. Tap "View All" to add new needs.',
                      textAlign: TextAlign.center,
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
      ],
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
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(need.title),
        subtitle: Text(
          '${need.description.length > 30 ? '${need.description.substring(0, 30)}...' : need.description}\n'
          'Due: ${DateFormat('MMM d, h:mm a').format(need.dueDate)}',
        ),
        trailing: _getStatusChip(need.status),
        isThreeLine: true,
        onTap: () {
          // Navigate to need details
          Navigator.pushNamed(
            context, 
            '/senior/need_details',
            arguments: need,
          );
        },
      ),
    );
  }

  Widget _getStatusChip(NeedStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case NeedStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case NeedStatus.inProgress:
        color = Colors.blue;
        label = 'In Progress';
        break;
      case NeedStatus.completed:
        color = Colors.green;
        label = 'Completed';
        break;
      case NeedStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
    }
    
    return Chip(
      label: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.all(0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge,
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
              'Family Members',
              Icons.family_restroom,
              Colors.purple,
              () => Navigator.pushNamed(context, '/senior/family_connections'),
            ),
            _buildActionCard(
              'Emergency Contacts',
              Icons.emergency,
              Colors.red,
              () => Navigator.pushNamed(context, '/senior/emergency_contacts'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
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