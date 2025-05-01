import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/widgets/need_card.dart';
import 'package:elderly_care_app/screens/family/need_details.dart';
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
  }

  bool _isFirstLoad = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstLoad) {
    _loadNeeds();
      _isFirstLoad = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNeeds() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final needs = await dbService.getSeniorNeeds(_getSenior().id);
      
      if (!mounted) return;
      
      setState(() {
        _needsList = needs;
        // Initialize GlobalKeys for each need
        _needKeys = { for (var need in needs) need.id: GlobalKey() };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = e.toString();
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

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          senior.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            onPressed: _disconnectSenior,
            tooltip: 'Disconnect Senior',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.person_outline),
              text: 'PROFILE',
            ),
            Tab(
              icon: Icon(Icons.list_alt),
              text: 'NEEDS',
            ),
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
                // Profile Header
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
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: senior.photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  senior.photoUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                  senior.name.isNotEmpty
                                      ? senior.name[0].toUpperCase()
                                      : '?',
                                    style: TextStyle(
                                      fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                  ),
                        ),
                                ),
                              ),
                      ),
                      SizedBox(height: 20),
                        Text(
                          senior.name,
                        style: TextStyle(
                          fontSize: 28,
                            fontWeight: FontWeight.bold,
                          color: Colors.white,
                          ),
                        ),
                      if (senior.emergencyModeActive) ...[
                        SizedBox(height: 12),
                          Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            ),
                          child: Row(
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
                                  fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      ],
                    ),
                  ),
                SizedBox(height: 24),
                
                // Contact Information
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.contact_mail,
                        color: theme.primaryColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                  'Contact Information',
                  style: TextStyle(
                        fontSize: 20,
                    fontWeight: FontWeight.bold,
                        color: Colors.black87,
                  ),
                ),
                  ],
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.email,
                          title: 'Email',
                          value: senior.email,
                          iconColor: theme.primaryColor,
                        ),
                        SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.phone,
                          title: 'Phone',
                          value: senior.phoneNumber ?? 'Not provided',
                          iconColor: theme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                
                // Location Information
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: theme.primaryColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                  'Location Information',
                  style: TextStyle(
                        fontSize: 20,
                    fontWeight: FontWeight.bold,
                        color: Colors.black87,
                  ),
                ),
                  ],
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.access_time,
                          title: 'Last Update',
                          value: lastLocationUpdate,
                          iconColor: theme.primaryColor,
                        ),
                        SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.map,
                          title: 'Coordinates',
                          value: senior.lastKnownLocation != null
                              ? '${senior.lastKnownLocation!.latitude.toStringAsFixed(4)}, '
                                '${senior.lastKnownLocation!.longitude.toStringAsFixed(4)}'
                              : 'No location data available',
                          iconColor: theme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                
                // Safety Settings
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.security,
                        color: theme.primaryColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                  'Safety Settings',
                  style: TextStyle(
                        fontSize: 20,
                    fontWeight: FontWeight.bold,
                        color: Colors.black87,
                  ),
                ),
                  ],
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _buildInfoRow(
                          icon: Icons.family_restroom,
                          title: 'Connected Family Members',
                          value: '${senior.connectedFamilyIds.length}',
                      iconColor: theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Needs Tab
          _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Loading needs...',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Failed to load needs',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadNeeds,
                            icon: Icon(Icons.refresh),
                            label: Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNeeds,
                      child: _needsList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.list_alt,
                                      size: 64,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  Text(
                                    'No needs added yet',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add a new need to get started',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                  ),
                                ),
                              ],
                              ),
                            )
                          : Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.list_alt,
                                          color: theme.primaryColor,
                                          size: 24,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        '${_needsList.length} Need${_needsList.length != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Spacer(),
                                      Text(
                                        'Due Date',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                              controller: _scrollController,
                                    padding: EdgeInsets.all(16),
                              itemCount: _needsList.length,
                              itemBuilder: (context, index) {
                                final need = _needsList[index];
                                final isHighlighted = need.id == (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?)?['needId'];
                                      return Card(
                                        key: _needKeys[need.id],
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: isHighlighted
                                              ? BorderSide(color: theme.primaryColor, width: 2)
                                              : BorderSide.none,
                                        ),
                                        margin: EdgeInsets.only(bottom: 16),
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => NeedDetailsScreen(
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
                                        assignedToId: familyMember.id,
                                      );
                                      
                                      final success = await dbService.updateNeed(updatedNeed);
                                      
                                      if (success) {
                                        _loadNeeds();
                                      } else {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Row(
                                                              children: [
                                                                Icon(Icons.error_outline, color: Colors.white),
                                                                SizedBox(width: 8),
                                                                Text('Failed to update need status'),
                                                              ],
                                                            ),
                                                            backgroundColor: Colors.red,
                                                            behavior: SnackBarBehavior.floating,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                                          content: Row(
                                                            children: [
                                                              Icon(Icons.error_outline, color: Colors.white),
                                                              SizedBox(width: 8),
                                                              Text('Error updating need: ${e.toString()}'),
                                                            ],
                                                          ),
                                                          backgroundColor: Colors.red,
                                                          behavior: SnackBarBehavior.floating,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                        ),
                                      );
                                    }
                                  },
                                                ),
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(16),
                                          child: Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: _getNeedTypeColor(need.type).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Icon(
                                                        _getNeedTypeIcon(need.type),
                                                        color: _getNeedTypeColor(need.type),
                                                        size: 24,
                                                      ),
                                                    ),
                                                    SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            need.title,
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            need.description,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey[600],
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.calendar_today,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      DateFormat('MMM d, yyyy').format(need.dueDate),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                    Spacer(),
                                                    Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(need.status).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            _getStatusIcon(need.status),
                                                            size: 16,
                                                            color: _getStatusColor(need.status),
                                                          ),
                                                          SizedBox(width: 6),
                                                          Text(
                                                            need.status.toString().split('.').last.toUpperCase(),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: _getStatusColor(need.status),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (need.status == NeedStatus.pending) ...[
                                                  SizedBox(height: 16),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: ElevatedButton.icon(
                                                          onPressed: () async {
                                                            try {
                                                              final dbService = Provider.of<DatabaseService>(
                                                                context,
                                                                listen: false,
                                                              );
                                                              
                                                              final updatedNeed = need.copyWith(
                                                                status: NeedStatus.completed,
                                                                assignedToId: familyMember.id,
                                                              );
                                                              
                                                              final success = await dbService.updateNeed(updatedNeed);
                                                              
                                                              if (success) {
                                                                _loadNeeds();
                                                              } else {
                                                                if (!mounted) return;
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  SnackBar(
                                                                    content: Row(
                                                                      children: [
                                                                        Icon(Icons.error_outline, color: Colors.white),
                                                                        SizedBox(width: 8),
                                                                        Text('Failed to update need status'),
                                                                      ],
                                                                    ),
                                                                    backgroundColor: Colors.red,
                                                                    behavior: SnackBarBehavior.floating,
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.circular(12),
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            } catch (e) {
                                                              if (!mounted) return;
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Row(
                                                                    children: [
                                                                      Icon(Icons.error_outline, color: Colors.white),
                                                                      SizedBox(width: 8),
                                                                      Text('Error updating need: ${e.toString()}'),
                                                                    ],
                                                                  ),
                                                                  backgroundColor: Colors.red,
                                                                  behavior: SnackBarBehavior.floating,
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(12),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          },
                                                          icon: Icon(Icons.check_circle),
                                                          label: Text('Mark as Completed'),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.green,
                                                            foregroundColor: Colors.white,
                                                            padding: EdgeInsets.symmetric(vertical: 12),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _addNeed,
              icon: Icon(Icons.add),
              label: Text('Add Need'),
              backgroundColor: theme.primaryColor,
              elevation: 4,
            )
          : null,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor ?? Colors.blue,
          size: 24,
        ),
        SizedBox(width: 16),
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
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getNeedTypeColor(NeedType type) {
    switch (type) {
      case NeedType.medication:
        return Colors.red;
      case NeedType.appointment:
        return Colors.purple;
      case NeedType.grocery:
        return Colors.green;
      case NeedType.other:
        return Colors.grey;
    }
  }

  IconData _getNeedTypeIcon(NeedType type) {
    switch (type) {
      case NeedType.medication:
        return Icons.medical_services;
      case NeedType.appointment:
        return Icons.calendar_today;
      case NeedType.grocery:
        return Icons.shopping_basket;
      case NeedType.other:
        return Icons.more_horiz;
    }
  }

  Color _getStatusColor(NeedStatus status) {
    switch (status) {
      case NeedStatus.pending:
        return Colors.orange;
      case NeedStatus.inProgress:
        return Colors.blue;
      case NeedStatus.completed:
        return Colors.green;
      case NeedStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(NeedStatus status) {
    switch (status) {
      case NeedStatus.pending:
        return Icons.pending;
      case NeedStatus.inProgress:
        return Icons.hourglass_empty;
      case NeedStatus.completed:
        return Icons.check_circle;
      case NeedStatus.cancelled:
        return Icons.cancel;
    }
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

