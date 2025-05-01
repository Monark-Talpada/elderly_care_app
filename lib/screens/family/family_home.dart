import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/screens/family/connect_senior.dart';
import 'package:elderly_care_app/screens/family/family_profile.dart';
import 'package:elderly_care_app/screens/family/emergency_map.dart';
import 'package:elderly_care_app/screens/family/senior_profile.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/widgets/need_card.dart';
import 'package:elderly_care_app/utils/navigation_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FamilyHomeScreen extends StatefulWidget {
  final FamilyMember family;

  const FamilyHomeScreen({Key? key, required this.family}) : super(key: key);

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  bool _isLoading = true;
  List<SeniorCitizen> _connectedSeniors = [];
  List<DailyNeed> _pendingNeeds = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      
      // Load connected seniors using the updated method from database_service.dart
      final seniors = await dbService.getConnectedSeniors(widget.family.id);
      
      // Load pending needs for all connected seniors
      List<DailyNeed> allNeeds = [];
      for (var senior in seniors) {
        final seniorNeeds = await dbService.getSeniorNeeds(senior.id);
        allNeeds.addAll(seniorNeeds.where((need) => need.status == NeedStatus.pending));
      }
      
      // Sort needs by due date (most urgent first)
      allNeeds.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      setState(() {
        _connectedSeniors = seniors;
        _pendingNeeds = allNeeds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
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

 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Family Dashboard',
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
              Navigator.pushNamed(context, '/family/profile');
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
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
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
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
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
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
                                  'Welcome, ${widget.family.name}',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'You are connected to ${_connectedSeniors.length} senior citizen${_connectedSeniors.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ConnectSeniorScreen(
                                          family: widget.family,
                                        ),
                                      ),
                                    ).then((_) => _loadData());
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Connect with a Senior'),
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
                        
                        // Connected seniors section
                        Row(
                          children: [
                            Icon(
                              Icons.group,
                              color: theme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Connected Seniors',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _connectedSeniors.isEmpty
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
                                    'You are not connected to any seniors yet',
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
                                itemCount: _connectedSeniors.length,
                                itemBuilder: (context, index) {
                                  final senior = _connectedSeniors[index];
                                  return _buildSeniorCard(senior);
                                },
                              ),
                        
                        const SizedBox(height: 32),
                        
                        // Pending needs section
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_active,
                              color: theme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Pending Needs',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _pendingNeeds.isEmpty
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
                                    'No pending needs at the moment',
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
                                itemCount: _pendingNeeds.length,
                                itemBuilder: (context, index) {
                                  final need = _pendingNeeds[index];
                                  final senior = _connectedSeniors.firstWhere(
                                    (s) => s.id == need.seniorId,
                                    orElse: () => SeniorCitizen(
                                      id: '',
                                      email: '',
                                      name: 'Unknown',
                                      createdAt: DateTime.now(),
                                    ),
                                  );
                                  
                                  return NeedCard(
                                    need: need,
                                    seniorName: senior.name,
                                    onStatusChange: (newStatus) async {
                                      try {
                                        final dbService = Provider.of<DatabaseService>(
                                          context,
                                          listen: false,
                                        );
                                        
                                        final updatedNeed = need.copyWith(
                                          status: newStatus,
                                          assignedToId: widget.family.id,
                                        );
                                        
                                        final success = await dbService.updateNeed(updatedNeed);
                                        
                                        if (success) {
                                          _loadData();
                                        } else {
                                          throw Exception('Failed to update need status');
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error updating need: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: _connectedSeniors.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final emergencySeniors = _connectedSeniors
                    .where((senior) => senior.emergencyModeActive)
                    .toList();
                
                if (emergencySeniors.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmergencyMapScreen(
                        seniors: emergencySeniors,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No seniors in emergency mode'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              backgroundColor: Colors.red,
              icon: const Icon(Icons.emergency),
              label: const Text('Emergency Map'),
              tooltip: 'Emergency Map',
            ),
    );
  }

  Widget _buildSeniorCard(SeniorCitizen senior) {
    final bool isEmergency = senior.emergencyModeActive;
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isEmergency
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeniorProfileScreen(
                senior: senior,
                familyMember: widget.family,
              ),
            ),
          ).then((_) => _loadData());
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
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    senior.name.isNotEmpty ? senior.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            senior.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isEmergency)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'EMERGENCY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.email,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            senior.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          senior.phoneNumber ?? 'No phone number',
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
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}