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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addEmergencyContact,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _emergencyContacts.isEmpty
              ? _buildEmptyState()
              : _buildEmergencyContactsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.contact_emergency,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Emergency Contacts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add family members or trusted contacts who can help in emergencies.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _addEmergencyContact,
            child: const Text('Add Emergency Contact'),
          ),
        ],
      ),
    );
  }

    Widget _buildEmergencyContactsList() {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _emergencyContacts.length,
        itemBuilder: (context, index) {
          final contact = _emergencyContacts[index];
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: contact.photoUrl != null
                    ? NetworkImage(contact.photoUrl!)
                    : null,
                child: contact.photoUrl == null
                    ? Text(contact.name.substring(0, 1).toUpperCase())
                    : null,
              ),
              title: Text(
                contact.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contact.relationship != null)
                    Text(
                      contact.relationship!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  Text(
                    contact.phoneNumber ?? 'No phone number',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: contact.phoneNumber != null
                    ? () => _launchCall(contact.phoneNumber!)
                    : null,
              ),
            ),
          );
        },
      );
    }

    void _launchCall(String phoneNumber) async {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer')),
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