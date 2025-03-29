import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:intl/intl.dart';

class DailyNeedsScreen extends StatefulWidget {
  const DailyNeedsScreen({Key? key}) : super(key: key);

  @override
  _DailyNeedsScreenState createState() => _DailyNeedsScreenState();
}

class _DailyNeedsScreenState extends State<DailyNeedsScreen> with SingleTickerProviderStateMixin {
  late AuthService _authService;
  late DatabaseService _databaseService;
  late TabController _tabController;
  
  bool _isLoading = true;
  List<DailyNeed> _allNeeds = [];
  SeniorCitizen? _senior;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _tabController = TabController(length: 3, vsync: this);
    _loadNeeds();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNeeds() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Get current senior using getCurrentSenior or getSeniorById
        final senior = await _databaseService.getCurrentSenior() ?? 
                      await _databaseService.getSeniorById(user.id);
        
        // Get needs for the current user
        final needs = await _databaseService.getSeniorNeeds(user.id);
        
        if (mounted) {
          setState(() {
            _senior = senior;
            _allNeeds = needs;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading needs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<DailyNeed> _getFilteredNeeds() {
    switch (_tabController.index) {
      case 0: // Active
        return _allNeeds.where((need) => 
            need.status == NeedStatus.pending || 
            need.status == NeedStatus.inProgress).toList();
      case 1: // Completed
        return _allNeeds.where((need) => 
            need.status == NeedStatus.completed).toList();
      case 2: // All
        return _allNeeds;
      default:
        return _allNeeds;
    }
  }

  Future<void> _updateNeedStatus(DailyNeed need, NeedStatus newStatus) async {
    try {
      final updatedNeed = need.copyWith(status: newStatus);
      final success = await _databaseService.updateNeed(updatedNeed);
      
      if (success) {
        setState(() {
          final index = _allNeeds.indexWhere((n) => n.id == need.id);
          if (index != -1) {
            _allNeeds[index] = updatedNeed;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Need status updated'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to update need status');
      }
    } catch (e) {
      print('Error updating need status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update need status'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteNeed(DailyNeed need) async {
    try {
      final success = await _databaseService.deleteNeed(need.id);
      
      if (success) {
        setState(() {
          _allNeeds.removeWhere((n) => n.id == need.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Need deleted'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to delete need');
      }
    } catch (e) {
      print('Error deleting need: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete need'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
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

    final filteredNeeds = _getFilteredNeeds();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Needs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
          onTap: (_) {
            setState(() {});  // Refresh to show newly filtered list
          },
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNeeds,
          child: filteredNeeds.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Center(
                        child: Text(
                          'No needs found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredNeeds.length,
                  itemBuilder: (context, index) => _buildNeedCard(filteredNeeds[index]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/senior/add_need');
          if (result == true) {
            _loadNeeds();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Add New Need',
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          need.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Due: ${DateFormat('MMM d, h:mm a').format(need.dueDate)}',
              style: TextStyle(
                color: need.dueDate.isBefore(DateTime.now()) && 
                      need.status != NeedStatus.completed ? 
                      Colors.red : null,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            _buildStatusChip(need.status),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16.0),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 100,
                ),
                child: SingleChildScrollView(
                  child: Text(need.description),
                ),
              ),
              const SizedBox(height: 16),
              if (need.isRecurring) ...[
                _buildInfoRow(Icons.repeat, 'Recurring: ${need.recurrenceRule ?? 'Yes'}'),
                const SizedBox(height: 16),
              ],
              if (need.assignedToId != null) ...[
                _buildInfoRow(Icons.person, 'Assigned to: ${need.assignedToId}'),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (need.status != NeedStatus.completed)
                    TextButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Complete'),
                      onPressed: () {
                        _updateNeedStatus(need, NeedStatus.completed);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context, 
                        '/senior/edit_need',
                        arguments: need,
                      );
                      if (result == true) {
                        _loadNeeds();
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () {
                      _showDeleteConfirmation(need);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(NeedStatus status) {
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
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showDeleteConfirmation(DailyNeed need) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${need.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNeed(need);
            },
            child: const Text('DELETE'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}