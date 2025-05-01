import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({Key? key}) : super(key: key);

  @override
  _EmergencyContactsScreenState createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<FamilyMember> _emergencyContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Get current senior's ID
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch connected family members
      final emergencyContacts = await databaseService.getConnectedFamilyMembers(currentUser.id);
      
      setState(() {
        _emergencyContacts = emergencyContacts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading emergency contacts: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load emergency contacts: $e')),
      );
    }
  }

  void _callContact(String phoneNumber) async {
    try {
      // You might want to use a phone calling plugin or platform channels 
      // for more robust phone calling functionality
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Call Contact'),
          content: Text('Call $phoneNumber?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // In a real app, implement actual phone calling
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Calling $phoneNumber')),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Call'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone call')),
      );
    }
  }

  void _sendSMS(String phoneNumber) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send SMS'),
          content: Text('Send SMS to $phoneNumber?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // In a real app, implement actual SMS sending
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sending SMS to $phoneNumber')),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Send'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch SMS')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
      ),
      body: _isLoading
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.primaryColor.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.primaryColor.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
              ),
              child: _emergencyContacts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadEmergencyContacts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _emergencyContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _emergencyContacts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            contact.name.substring(0, 1).toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 24,
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
                                            Text(
                                              contact.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (contact.relationship != null) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: theme.primaryColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  contact.relationship!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.primaryColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (contact.phoneNumber != null)
                                        IconButton(
                                          icon: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: theme.primaryColor.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.phone,
                                              color: theme.primaryColor,
                                              size: 24,
                                            ),
                                          ),
                                          onPressed: () => _launchCall(contact.phoneNumber!),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
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
                                                contact.email,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (contact.phoneNumber != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.phone,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                contact.phoneNumber!,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.contact_emergency,
              size: 50,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Emergency Contacts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Add family members or trusted contacts who can help in emergencies.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addEmergencyContact,
            icon: Icon(Icons.person_add, color: theme.primaryColor),
            label: Text(
              'Add Emergency Contact',
              style: TextStyle(color: theme.primaryColor),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _launchCall(String phoneNumber) async {
    try {
      // Clean the phone number - remove spaces and special characters
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Try to launch the phone dialer
      final result = await launchUrl(
        Uri.parse('tel:$cleanNumber'),
        mode: LaunchMode.externalApplication,
      );
      
      if (!result) {
        // If the first attempt fails, try with a different format
        final alternativeResult = await launchUrl(
          Uri.parse('tel://$cleanNumber'),
          mode: LaunchMode.externalApplication,
        );
        
        if (!alternativeResult) {
          throw Exception('Could not launch phone dialer. Please check your device settings.');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () async {
              // Open app settings to check permissions
              await launchUrl(
                Uri.parse('app-settings:'),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ),
      );
    }
  }

  void _addEmergencyContact() {
    // Navigate to a screen to add a new emergency contact
    Navigator.pushNamed(context, '/senior/add_emergency_contact').then((_) {
      // Refresh contacts after returning
      _loadEmergencyContacts();
    });
  }
}