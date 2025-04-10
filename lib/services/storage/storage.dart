import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class Storage with ChangeNotifier {
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> _products = []; // Store product details
  bool _isLoading = false;
  bool _isUploading = false;
  DocumentSnapshot? _lastDocument;
  String? _profileImageUrl;

  List<Map<String, dynamic>> get products => _products;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get profileImageUrl => _profileImageUrl;

  // Clear products list (useful for refresh operations)
  void clearProducts() {
    _products.clear();
    _lastDocument = null;
    notifyListeners();
  }

  // Fetch images using pagination
  Future<void> fetchImages() async {
    if (_isLoading) return; // Prevent multiple simultaneous fetches

    _isLoading = true;
    notifyListeners();

    try {
      Query query = _firestore
          .collection('Products')
          .orderBy('createdAt', descending: true)
          .limit(10);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;

        for (var doc in snapshot.docs) {
          // Fetch user details for the product
          String userId = doc['userId'] ?? '';
          
          String username = 'Unknown User';
          String? profileImageUrl;
          
          try {
            // Only fetch user details if userId exists
            if (userId.isNotEmpty) {
              DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
              if (userDoc.exists) {
                username = userDoc['username'] ?? 'Unknown User';
                
                // Get the profile image URL from the path
                String? profileImagePath = userDoc['profileImagePath'];
                if (profileImagePath != null && profileImagePath.isNotEmpty) {
                  profileImageUrl = await _firebaseStorage.ref(profileImagePath).getDownloadURL();
                }
              }
            }
          } catch (e) {
            print('Error fetching user details: $e');
            // Continue with default values if user details can't be fetched
          }

          // Add product details to the list
          _products.add({
            'id': doc.id, // Store document ID for easy deletion
            'image': doc['image'],
            'productName': doc['productName'],
            'description': doc['description'],
            'category': doc['category'],
            'price': doc['price'],
            'userId': userId,
            'username': username,
            'profileImageUrl': profileImageUrl,
            'createdAt': doc['createdAt'],
          });
        }
      }
    } catch (e) {
      print('Error fetching products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete image and product document
  Future<void> deleteImage(String imageUrl, String productId, BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Confirmation dialog
      bool confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Confirm Delete"),
            content: const Text("Are you sure you want to delete this product?"),
            actions: <Widget>[
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text("Delete"),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ?? false;

      if (!confirmDelete) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Delete the product document from Firestore first
      await _firestore.collection('Products').doc(productId).delete();
      
      // Then try to delete from Firebase Storage if the URL exists
      if (imageUrl.isNotEmpty) {
        try {
          // Extract reference from URL
          Reference ref = _firebaseStorage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          print('Error deleting image from storage: $e');
          // Continue even if image deletion fails
        }
      }

      // Remove from local list
      _products.removeWhere((product) => product['id'] == productId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product deleted successfully"))
      );
    } catch (e) {
      print('Error deleting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting product: ${e.toString()}"))
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Upload image
  Future<String?> uploadImage(File imageFile, {String folder = 'products'}) async {
    _isUploading = true;
    notifyListeners();

    try {
      // Generate unique filename
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      Reference storageReference = _firebaseStorage.ref().child('images/$folder/$fileName');

      // Upload with metadata
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded_by': 'tjmarket_app'},
      );
      
      UploadTask uploadTask = storageReference.putFile(imageFile, metadata);
      TaskSnapshot taskSnapshot = await uploadTask;
      
      // Get download URL
      String imageUrl = await taskSnapshot.ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // Upload profile picture
  Future<void> uploadProfilePicture(String userId) async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Optimize image size
        imageQuality: 85, // Reduce quality slightly for better performance
      );

      if (pickedFile == null) return; // User cancelled

      String fileName = "profile_${userId}_${DateTime.now().millisecondsSinceEpoch}";
      Reference storageReference = _firebaseStorage.ref().child('images/profiles/$fileName');

      // Upload with better metadata
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'user_id': userId, 'type': 'profile'},
      );
      
      UploadTask uploadTask = storageReference.putFile(File(pickedFile.path), metadata);
      await uploadTask.whenComplete(() {});
      String imageUrl = await storageReference.getDownloadURL();

      // Update user document with profile image info
      await _firestore.collection('users').doc(userId).update({
        'profileImagePath': storageReference.fullPath,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      _profileImageUrl = imageUrl;
      notifyListeners();
      
    } catch (e) {
      print("Error uploading profile picture: $e");
    }
  }

  // Fetch profile picture URL
  Future<void> fetchProfilePicture(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        String? profileImagePath = userDoc['profileImagePath'];
        
        if (profileImagePath != null && profileImagePath.isNotEmpty) {
          _profileImageUrl = await _firebaseStorage.ref(profileImagePath).getDownloadURL();
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error fetching profile picture: $e");
    }
  }
}