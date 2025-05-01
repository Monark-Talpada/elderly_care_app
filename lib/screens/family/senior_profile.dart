import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/widgets/need_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SeniorProfileScreen extends StatefulWidget {
  final SeniorCitizen? senior; // Made nullable to handle route arguments
  final FamilyMember? familyMember; // Made nullable to handle route arguments

  const SeniorProfileScreen({
    Key? key,
    this.senior,
    this.familyMember,
  }) : super(key: key);

  @override
  State<SeniorProfileScreen> createState() => _SeniorProfileScreenState();
}

class _SeniorProfileScreenState extends State<SeniorProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<DailyNeed> _needsList = [];
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  Map<String, GlobalKey> _needKeys = {}; // Keys for each NeedCard

  @override
  void initState() {
    super.initState();
    // Extract arguments from the route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final int? tabIndex = args?['tabIndex'];
      final String? needId = args?['needId'];

      // Set the NEEDS tab if tabIndex is provided
      if (tabIndex != null && tabIndex == 1) {
        _tabController.index = tabIndex;
      }

      // Scroll to the specific need if needId is provided
      if (needId != null && _needKeys.containsKey(needId)) {
        Future.delayed(const Duration(milliseconds: 300), () {
          Scrollable.ensureVisible(
            _needKeys[needId]!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
    });

    _tabController = TabController(length: 2, vsync: this);
    _loadNeeds();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNeeds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final needs = await dbService.getSeniorNeeds(_getSenior().id);
      
      setState(() {
        _needsList = needs;
        // Initialize GlobalKeys for each need
        _needKeys = { for (var need in needs) need.id: GlobalKey() };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load needs: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Helper to get senior from widget or route arguments
  SeniorCitizen _getSenior() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return args?['senior'] as SeniorCitizen? ?? widget.senior!;
  }

  // Helper to get family member from widget or route arguments
  FamilyMember _getFamilyMember() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return args?['familyMember'] as FamilyMember? ?? widget.familyMember!;
  }

  Future<void> _addNeed() async {
    final result = await showDialog<DailyNeed>(
      context: context,
      builder: (context) => _AddNeedDialog(seniorId: _getSenior().id),
    );

    if (result != null) {
      try {
        final dbService = Provider.of<DatabaseService>(context, listen: false);
        final needId = await dbService.addNeed(result);
        
        if (needId != null) {
          _loadNeeds();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Need added successfully')),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add need')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding need: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _disconnectSenior() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Senior'),
        content: Text(
          'Are you sure you want to disconnect from ${_getSenior().name}? '
          'You will no longer receive updates or emergency alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DISCONNECT'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbService = Provider.of<DatabaseService>(context, listen: false);
        
        // Update family member
        final updatedFamily = _getFamilyMember().copyWith(
          connectedSeniorIds: _getFamilyMember().connectedSeniorIds
              .where((id) => id != _getSenior().id)
              .toList(),
        );
        final familyUpdated = await dbService.updateFamilyMember(updatedFamily);
        
        if (!familyUpdated) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update family member')),
          );
          return;
        }
        
        // Update senior
        final updatedSenior = _getSenior().copyWith(
          connectedFamilyIds: _getSenior().connectedFamilyIds
              .where((id) => id != _getFamilyMember().id)
              .toList(),
        );
        final seniorUpdated = await dbService.updateSenior(updatedSenior);
        
        if (!seniorUpdated) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update senior')),
          );
          return;
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully disconnected from senior'),
          ),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disconnecting from senior: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final senior = _getSenior();
    final familyMember = _getFamilyMember();
    final lastLocationUpdate = senior.lastLocationUpdate != null
        ? DateFormat('MMM d, yyyy h:mm a').format(senior.lastLocationUpdate!)
        : 'Never';

    return Scaffold(
      appBar: AppBar(
        title: Text(senior.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            onPressed: _disconnectSenior,
            tooltip: 'Disconnect Senior',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'PROFILE'),
            Tab(text: 'NEEDS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Profile Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: senior.emergencyModeActive
                        ? const BorderSide(color: Colors.red, width: 2)
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: senior.photoUrl != null
                              ? NetworkImage(senior.photoUrl!)
                              : null,
                          child: senior.photoUrl == null
                              ? Text(
                                  senior.name.isNotEmpty
                                      ? senior.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          senior.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (senior.emergencyModeActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'EMERGENCY MODE ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.email,
                          title: 'Email',
                          value: senior.email,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          icon: Icons.phone,
                          title: 'Phone',
                          value: senior.phoneNumber ?? 'Not provided',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Location Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.access_time,
                          title: 'Last Update',
                          value: lastLocationUpdate,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          icon: Icons.location_on,
                          title: 'Coordinates',
                          value: senior.lastKnownLocation != null
                              ? '${senior.lastKnownLocation!.latitude.toStringAsFixed(4)}, '
                                '${senior.lastKnownLocation!.longitude.toStringAsFixed(4)}'
                              : 'No location data available',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Safety Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.family_restroom,
                          title: 'Connected Family Members',
                          value: '${senior.connectedFamilyIds.length}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Needs Tab
          _isLoading
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
                            onPressed: _loadNeeds,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNeeds,
                      child: _needsList.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 100),
                                Center(
                                  child: Text(
                                    'No needs added yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _needsList.length,
                              itemBuilder: (context, index) {
                                final need = _needsList[index];
                                final isHighlighted = need.id == (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?)?['needId'];
                                return NeedCard(
                                  key: _needKeys[need.id], // Assign GlobalKey
                                  need: need,
                                  seniorName: senior.name,
                                  isHighlighted: isHighlighted, // Pass highlight flag
                                  onStatusChange: (newStatus) async {
                                    try {
                                      final dbService = Provider.of<DatabaseService>(
                                        context,
                                        listen: false,
                                      );
                                      
                                      final updatedNeed = need.copyWith(
                                        status: newStatus,
                                        assignedToId: familyMember.id,
                                      );
                                      
                                      final success = await dbService.updateNeed(updatedNeed);
                                      
                                      if (success) {
                                        _loadNeeds();
                                      } else {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to update need status'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (!mounted) return;
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
                    ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _addNeed,
              child: const Icon(Icons.add),
              tooltip: 'Add Need',
            )
          : null,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.blue,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddNeedDialog extends StatefulWidget {
  final String seniorId;

  const _AddNeedDialog({required this.seniorId});

  @override
  State<_AddNeedDialog> createState() => _AddNeedDialogState();
}

class _AddNeedDialogState extends State<_AddNeedDialog> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  NeedType _type = NeedType.other;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Need'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                onSaved: (value) => _title = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<NeedType>(
                decoration: const InputDecoration(labelText: 'Type'),
                value: _type,
                items: NeedType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last.capitalize()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _type = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Due Date'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(_dueDate)),
                onTap: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (selectedDate != null) {
                    setState(() {
                      _dueDate = selectedDate;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              final newNeed = DailyNeed(
                id: '', // Database will generate this
                seniorId: widget.seniorId,
                title: _title,
                description: _description,
                type: _type,
                status: NeedStatus.pending,
                dueDate: _dueDate,
                createdAt: DateTime.now(),
              );
              Navigator.of(context).pop(newNeed);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}