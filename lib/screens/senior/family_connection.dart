import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';


class FamilyConnectionsScreen extends StatefulWidget {
  const FamilyConnectionsScreen({Key? key}) : super(key: key);

  @override
  _FamilyConnectionsScreenState createState() => _FamilyConnectionsScreenState();
}

class _FamilyConnectionsScreenState extends State<FamilyConnectionsScreen> {
  late DatabaseService _databaseService;
  late AuthService _authService;
  bool _isLoading = true;
  List<FamilyMember> _familyMembers = [];

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = _authService.currentUser;
      if (user != null) {
        final familyMembers = await _databaseService.getConnectedFamilyMembers(user.id);

        if (mounted) {
          setState(() {
            _familyMembers = familyMembers;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading family members: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Connections'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _familyMembers.isEmpty
              ? _buildEmptyState()
              : _buildFamilyList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add family member screen
          // You can implement this later
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add family member feature coming soon')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.family_restroom,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No family members connected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Connect with your family members to get help and support when you need it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to add family member screen
              // You can implement this later
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add family member feature coming soon')),
              );
            },
            child: const Text('Connect Family Member'),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyList() {
    return RefreshIndicator(
      onRefresh: _loadFamilyMembers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _familyMembers.length,
        itemBuilder: (context, index) {
          final member = _familyMembers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: CircleAvatar(
                radius: 30,
                backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
                child: member.photoUrl == null
                    ? Text(
                        member.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 24),
                      )
                    : null,
              ),
              title: Text(
                member.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (member.relationship != null)
                    Text(
                      member.relationship!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 2),
                  Text(member.email),
                  if (member.phoneNumber != null) ...[
                    const SizedBox(height: 2),
                    Text(member.phoneNumber!),
                  ],
                ],
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.call),
                onPressed: () async {
                  if (member.phoneNumber != null && member.phoneNumber!.isNotEmpty) {
                    final Uri launchUri = Uri(scheme: 'tel', path: member.phoneNumber);
                    if (await canLaunchUrl(launchUri)) {
                      await launchUrl(launchUri);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not launch dialer for ${member.phoneNumber}')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No phone number available for ${member.name}')),
                    );
                  }
                },
              ),

              onTap: () {
                // Show member details
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => _buildMemberDetailsSheet(member),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemberDetailsSheet(FamilyMember member) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
                        child: member.photoUrl == null
                            ? Text(
                                member.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 40),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (member.relationship != null)
                        Text(
                          member.relationship!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                _buildInfoRow(Icons.email, 'Email', member.email),
                if (member.phoneNumber != null)
                  _buildInfoRow(Icons.phone, 'Phone', member.phoneNumber!),
                const SizedBox(height: 24),
                const Text(
                  'Notification Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                _buildInfoRow(
                  member.notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                  'Notifications',
                  member.notificationsEnabled ? 'Enabled' : 'Disabled',
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      foregroundColor: Colors.red[800],
                    ),
                    onPressed: () {
                      // Implement disconnect functionality
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Disconnect feature coming soon')),
                      );
                    },
                    child: const Text('Disconnect Family Member'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}