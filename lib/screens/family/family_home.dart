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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),   
            onPressed: () {
                Navigator.pushNamed(context, '/family/profile');
            },
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
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
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${widget.family.name}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You are connected to ${_connectedSeniors.length} senior citizen${_connectedSeniors.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 16),
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
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Connected seniors section
                        const Text(
                          'Connected Seniors',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _connectedSeniors.isEmpty
                            ? const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      'You are not connected to any seniors yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
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
                        
                        const SizedBox(height: 24),
                        
                        // Pending needs section
                        const Text(
                          'Pending Needs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _pendingNeeds.isEmpty
                            ? const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      'No pending needs at the moment',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
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
                                        
                                        // Use updateNeed method from database_service.dart
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
          : FloatingActionButton(
              onPressed: () {
                // Check if any senior is in emergency mode
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
                    ),
                  );
                }
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.emergency),
              tooltip: 'Emergency Map',
            ),
    );
  }

  Widget _buildSeniorCard(SeniorCitizen senior) {
    final bool isEmergency = senior.emergencyModeActive;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  senior.name.isNotEmpty ? senior.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
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
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
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
                    const SizedBox(height: 4),
                    Text(
                      senior.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      senior.phoneNumber ?? 'No phone number',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}