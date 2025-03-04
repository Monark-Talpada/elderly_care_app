import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/widgets/need_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SeniorProfileScreen extends StatefulWidget {
  final SeniorCitizen senior;
  final FamilyMember familyMember;

  const SeniorProfileScreen({
    Key? key,
    required this.senior,
    required this.familyMember,
  }) : super(key: key);

  @override
  State<SeniorProfileScreen> createState() => _SeniorProfileScreenState();
}

class _SeniorProfileScreenState extends State<SeniorProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<DailyNeed> _needsList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNeeds();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNeeds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final needs = await dbService.getSeniorNeeds(widget.senior.id);
      
      setState(() {
        _needsList = needs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load needs: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _addNeed() async {
    final result = await showDialog<DailyNeed>(
      context: context,
      builder: (context) => _AddNeedDialog(seniorId: widget.senior.id),
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
          'Are you sure you want to disconnect from ${widget.senior.name}? '
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
        final updatedFamily = widget.familyMember.copyWith(
          connectedSeniorIds: widget.familyMember.connectedSeniorIds
              .where((id) => id != widget.senior.id)
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
        final updatedSenior = widget.senior.copyWith(
          connectedFamilyIds: widget.senior.connectedFamilyIds
              .where((id) => id != widget.familyMember.id)
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
    final lastLocationUpdate = widget.senior.lastLocationUpdate != null
        ? DateFormat('MMM d, yyyy h:mm a').format(widget.senior.lastLocationUpdate!)
        : 'Never';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.senior.name),
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
                    side: widget.senior.emergencyModeActive
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
                          backgroundImage: widget.senior.photoUrl != null
                              ? NetworkImage(widget.senior.photoUrl!)
                              : null,
                          child: widget.senior.photoUrl == null
                              ? Text(
                                  widget.senior.name.isNotEmpty
                                      ? widget.senior.name[0].toUpperCase()
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
                          widget.senior.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.senior.emergencyModeActive)
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
                          value: widget.senior.email,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          icon: Icons.phone,
                          title: 'Phone',
                          value: widget.senior.phoneNumber ?? 'Not provided',
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
                          value: widget.senior.lastKnownLocation != null
                              ? '${widget.senior.lastKnownLocation!.latitude.toStringAsFixed(4)}, '
                                '${widget.senior.lastKnownLocation!.longitude.toStringAsFixed(4)}'
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
                          icon: Icons.sensors,
                          title: 'Fall Detection',
                          value: widget.senior.fallDetectionEnabled ? 'Enabled' : 'Disabled',
                          valueColor: widget.senior.fallDetectionEnabled
                              ? Colors.green
                              : Colors.red,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          icon: Icons.family_restroom,
                          title: 'Connected Family Members',
                          value: '${widget.senior.connectedFamilyIds.length}',
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
                              padding: const EdgeInsets.all(16),
                              itemCount: _needsList.length,
                              itemBuilder: (context, index) {
                                final need = _needsList[index];
                                return NeedCard(
                                  need: need,
                                  seniorName: widget.senior.name,
                                  onStatusChange: (newStatus) async {
                                    try {
                                      final dbService = Provider.of<DatabaseService>(
                                        context,
                                        listen: false,
                                      );
                                      
                                      final updatedNeed = need.copyWith(
                                        status: newStatus,
                                        assignedToId: widget.familyMember.id,
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

// Extension to capitalize enum strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}