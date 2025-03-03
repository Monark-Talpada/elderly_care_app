import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/screens/senior/book_volunteer.dart';

class VolunteerSelectionScreen extends StatefulWidget {
  final DailyNeed? need;

  const VolunteerSelectionScreen({
    Key? key,
    this.need,
  }) : super(key: key);

  @override
  _VolunteerSelectionScreenState createState() => _VolunteerSelectionScreenState();
}

class _VolunteerSelectionScreenState extends State<VolunteerSelectionScreen> {
  late DatabaseService _databaseService;
  List<Volunteer> _volunteers = [];
  bool _isLoading = true;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadVolunteers();
  }

  Future<void> _loadVolunteers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load available volunteers - you may want to filter based on need type
      final volunteers = await _databaseService.getAvailableVolunteers();
      
      setState(() {
        _volunteers = volunteers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading volunteers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load volunteers: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Volunteer> get _filteredVolunteers {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return _volunteers;
    }
    
    final query = _searchQuery!.toLowerCase();
    return _volunteers.where((volunteer) {
      return volunteer.name.toLowerCase().contains(query) || 
             volunteer.skills.any((skill) => skill.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Volunteer'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search volunteers by name or skills...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Volunteers list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVolunteers.isEmpty
                    ? const Center(child: Text('No volunteers found'))
                    : RefreshIndicator(
                        onRefresh: _loadVolunteers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredVolunteers.length,
                          itemBuilder: (context, index) {
                            final volunteer = _filteredVolunteers[index];
                            return _buildVolunteerCard(volunteer);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerCard(Volunteer volunteer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookVolunteerScreen(
                volunteerId: volunteer.id,
                need: widget.need,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: volunteer.photoUrl != null
                        ? NetworkImage(volunteer.photoUrl!)
                        : null,
                    child: volunteer.photoUrl == null
                        ? Text(volunteer.name[0])
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          volunteer.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (volunteer.isVerified)
                          Row(
                            children: const [
                              Icon(Icons.verified, color: Colors.blue, size: 16),
                              SizedBox(width: 4),
                              Text('Verified Volunteer'),
                            ],
                          ),
                        if (volunteer.rating != null)
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('${volunteer.rating!.toStringAsFixed(1)} (${volunteer.ratingCount})'),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Skills',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: volunteer.skills.map((skill) {
                  return Chip(label: Text(skill));
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text('Tap to view availability'),
                  Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}