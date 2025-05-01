import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/services/auth_service.dart';

class VolunteerProfileScreen extends StatefulWidget {
  final Volunteer volunteer;
  final bool isAdmin; // To determine if verification button should be shown

  const VolunteerProfileScreen({
    Key? key,
    required this.volunteer,
    this.isAdmin = false, // Default to false for regular users
  }) : super(key: key);

  @override
  _VolunteerProfileScreenState createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;
  bool _isVerifying = false;

  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _experienceYearsController;
  List<String> _selectedSkills = [];
  List<String> _selectedAreas = [];
  final TextEditingController _skillController = TextEditingController();
  late TextEditingController _areaController;

  // Mock reviews data - In a real app, you'd fetch this from your database
  final List<Map<String, dynamic>> _reviews = [];

  // Available skills options
  final List<String> _availableSkills = [
    'Companionship',
    'Meal Preparation',
    'Transportation',
    'Shopping',
    'Medication Reminders',
    'Light Housekeeping',
    'Technology Help',
    'Cognitive Activities',
    'Physical Activities',
  ];

  @override
  void initState() {
    super.initState();
    print('Loading volunteer data from Firebase...');
    print('Initial serving areas: ${widget.volunteer.servingAreas}');
    
    // Initialize controllers with existing data
    _nameController = TextEditingController(text: widget.volunteer.name);
    _phoneController = TextEditingController(
      text: widget.volunteer.phoneNumber ?? '',
    );
    _bioController = TextEditingController(text: widget.volunteer.bio ?? '');
    _experienceYearsController = TextEditingController(
      text: widget.volunteer.experienceYears.toString(),
    );
    _areaController = TextEditingController();

    // Initialize selected values
    _selectedSkills = List.from(widget.volunteer.skills);
    _selectedAreas = List.from(widget.volunteer.servingAreas);
    print('Loaded serving areas: $_selectedAreas');

    // Load reviews
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    // This would typically fetch reviews from your database service
    // For now, let's create some sample reviews if the volunteer has reviews
    setState(() {
      if (widget.volunteer.ratingCount != null &&
          widget.volunteer.ratingCount! > 0) {
        // Some sample reviews
        _reviews.addAll([
          {
            'reviewerName': 'John D.',
            'rating': 5.0,
            'date': DateTime.now().subtract(const Duration(days: 15)),
            'comment':
                'Very helpful and caring. Always on time and goes above and beyond.',
          },
          {
            'reviewerName': 'Mary S.',
            'rating': 4.0,
            'date': DateTime.now().subtract(const Duration(days: 45)),
            'comment': 'Good communication and very patient. Would recommend.',
          },
        ]);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _experienceYearsController.dispose();
    _skillController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('Saving profile with areas: $_selectedAreas');
      // Create updated volunteer object
      final updatedVolunteer = widget.volunteer.copyWith(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        experienceYears: int.tryParse(_experienceYearsController.text) ?? 0,
        skills: _selectedSkills,
        servingAreas: _selectedAreas,
      );

      print('Updated volunteer object created with areas: ${updatedVolunteer.servingAreas}');
      
      // Save to database
      await _databaseService.updateVolunteer(updatedVolunteer);
      print('Profile saved successfully to Firebase');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving profile: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    } finally {
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
        title: const Text('Volunteer Profile'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildProfileStats(),
                    const SizedBox(height: 24),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 24),
                    _buildSkillsSection(),
                    const SizedBox(height: 24),
                    _buildServingAreasSection(),
                    const SizedBox(height: 24),
                    _buildReviewsSection(),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 50),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Save Profile',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage:
                      widget.volunteer.photoUrl != null
                          ? NetworkImage(widget.volunteer.photoUrl!)
                          : null,
                  child:
                      widget.volunteer.photoUrl == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child:
                    widget.volunteer.isVerified
                        ? const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 24,
                          )
                        : const Icon(
                            Icons.pending,
                            color: Colors.grey,
                            size: 24,
                          ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.volunteer.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.volunteer.email,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Member since: ${DateFormat('MMM yyyy').format(widget.volunteer.createdAt)}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatColumn(
              '${widget.volunteer.totalHoursVolunteered}',
              'Hours',
              Icons.access_time,
              color: Theme.of(context).primaryColor,
            ),
            _buildStatColumn(
              widget.volunteer.rating?.toStringAsFixed(1) ?? '-',
              'Rating',
              Icons.star,
              color: Colors.amber,
            ),
            _buildStatColumn(
              '${widget.volunteer.ratingCount ?? 0}',
              'Reviews',
              Icons.rate_review,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    String value,
    String label,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color?.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.person),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.phone),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.description),
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a short bio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _experienceYearsController,
              decoration: InputDecoration(
                labelText: 'Years of Experience',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.work),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter years of experience';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology_outlined,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Your Skills',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your skills:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillController,
                    decoration: InputDecoration(
                      hintText: 'Enter a skill',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_skillController.text.trim().isNotEmpty) {
                      setState(() {
                        if (!_selectedSkills.contains(_skillController.text.trim())) {
                          _selectedSkills.add(_skillController.text.trim());
                        }
                        _skillController.clear();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedSkills.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'No skills added yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _selectedSkills.map((skill) {
                  return Chip(
                    label: Text(skill),
                    onDeleted: () {
                      setState(() {
                        _selectedSkills.remove(skill);
                      });
                    },
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    deleteIconColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServingAreasSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Areas You Serve',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Add the areas where you can volunteer:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _areaController,
                    decoration: InputDecoration(
                      hintText: 'Enter an area or address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_areaController.text.trim().isNotEmpty) {
                      setState(() {
                        if (!_selectedAreas.contains(_areaController.text.trim())) {
                          _selectedAreas.add(_areaController.text.trim());
                        }
                        _areaController.clear();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedAreas.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'No areas added yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _selectedAreas.map((area) {
                  return Chip(
                    label: Text(area),
                    onDeleted: () {
                      setState(() {
                        _selectedAreas.remove(area);
                      });
                    },
                    backgroundColor: Colors.green.withOpacity(0.1),
                    deleteIconColor: Colors.green,
                    labelStyle: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star_outline,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Reviews',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_reviews.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reviews.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  return _buildReviewItem(review);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final rating = review['rating'] as double;
    final formattedDate = DateFormat('MMM d, yyyy').format(review['date'] as DateTime);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review['reviewerName'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating.floor()
                    ? Icons.star
                    : (index < rating ? Icons.star_half : Icons.star_border),
                color: Colors.amber,
                size: 20,
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            review['comment'],
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
