import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:elderly_care_app/screens/senior/need_details.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
        final senior = await _databaseService.getCurrentSenior() ?? 
                      await _databaseService.getSeniorById(user.id);
        
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
      final success = await _databaseService.deleteNeed(need.id, _senior!.id);
      
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

    final theme = Theme.of(context);
    final filteredNeeds = _getFilteredNeeds();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daily Needs',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
          onTap: (_) {
            setState(() {});  // Refresh to show newly filtered list
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadNeeds,
          child: filteredNeeds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No needs found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add),
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeniorNeedDetailsScreen(need: need),
            ),
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
        icon = Icons.pending;
        break;
      case NeedStatus.inProgress:
        color = Colors.blue;
        label = 'In Progress';
        icon = Icons.hourglass_empty;
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
}