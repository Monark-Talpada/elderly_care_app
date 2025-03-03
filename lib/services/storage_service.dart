import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Upload profile image for a user and return download URL
  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final storageRef = _storage.ref().child('profile_images/$fileName');
      
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }
  
  // Upload any document related to needs (e.g., medical prescriptions)
  Future<String?> uploadNeedDocument(File documentFile, String needId) async {
    try {
      final fileName = 'need_${needId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(documentFile.path)}';
      final storageRef = _storage.ref().child('need_documents/$fileName');
      
      final uploadTask = storageRef.putFile(documentFile);
      final snapshot = await uploadTask.whenComplete(() {});
      
      // Get download URL
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading need document: $e');
      return null;
    }
  }
  
  // Delete a file from storage using its URL
  Future<bool> deleteFile(String fileUrl) async {
    try {
      // Extract reference from URL
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }
  
  // Upload emergency-related images (e.g., fall detection evidence)
  Future<String?> uploadEmergencyImage(File imageFile, String seniorId) async {
    try {
      final fileName = 'emergency_${seniorId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final storageRef = _storage.ref().child('emergency_images/$fileName');
      
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading emergency image: $e');
      return null;
    }
  }
  
  // Get a list of URLs for all documents related to a specific need
  Future<List<String>> getNeedDocumentUrls(String needId) async {
    try {
      final ListResult result = await _storage.ref().child('need_documents').list();
      final List<Reference> allFiles = result.items;
      final needFiles = allFiles.where((ref) => ref.name.contains('need_$needId')).toList();
      
      List<String> urls = [];
      for (var file in needFiles) {
        String url = await file.getDownloadURL();
        urls.add(url);
      }
      
      return urls;
    } catch (e) {
      print('Error getting need document URLs: $e');
      return [];
    }
  }
}