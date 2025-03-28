import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/utils/navigation_utils.dart';
import 'package:elderly_care_app/screens/senior/emergency_button.dart';
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
              backgroundImage:
                  _senior!.photoUrl != null ? NetworkImage(_senior!.photoUrl!) : null,
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
      onTap: _navigateToEmergencyButton,
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
                Navigator.pushNamed(context, '/senior/daily_needs').then((_) {
                  _loadSeniorData();
                });
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _upcomingNeeds.isEmpty
            ? Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'No upcoming needs',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "View All" to add new needs',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
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
            _buildFamilyMembersCard(),
            _buildActionCard(
              'Emergency Contacts',
              Icons.emergency,
              Colors.red,
              () => Navigator.pushNamed(context, '/senior/emergency_contacts'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_connectedFamilyMembers.isNotEmpty) _buildFamilyMembersSection(),
      ],
    );
  }

  Widget _buildFamilyMembersCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/senior/family_connections'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.family_restroom,
                    size: 48,
                    color: Colors.purple,
                  ),
                  if (_connectedFamilyMembers.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _connectedFamilyMembers.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Family Members',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_connectedFamilyMembers.length} connected',
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

  Widget _buildFamilyMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Connected Family',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/senior/family_connections')
                    .then((_) {
                  _loadSeniorData();
                });
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount:
                _connectedFamilyMembers.length > 5 ? 5 : _connectedFamilyMembers.length,
            itemBuilder: (context, index) {
              final member = _connectedFamilyMembers[index];
              return _buildFamilyMemberCard(member);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyMemberCard(FamilyMember member) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {},
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage:
                    member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
                child: member.photoUrl == null
                    ? Text(member.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 18))
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              if (member.relationship != null)
                Text(
                  member.relationship!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ),
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