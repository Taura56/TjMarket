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
          String userId = doc['userId'];
          DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

          // Get the profile image URL from the path
        String? profileImagePath = userDoc['profileImagePath'];
        String? profileImageUrl;
        if (profileImagePath != null) {
          profileImageUrl = await _firebaseStorage.ref(profileImagePath).getDownloadURL();
        }

          // Add product details to the list
           _products.add({
          'image': doc['image'],
          'productName': doc['productName'],
          'description': doc['description'],
          'category': doc['category'],
          'price': doc['price'],
          'userId': userId,
          'username': userDoc['username'],
          'profileImageUrl': profileImageUrl,
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

  // Delete image
  Future<void> deleteImage(String imageUrl, String? image, BuildContext context) async {
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

    // Delete from Firebase Storage
    final String path = extractPathFromUrl(imageUrl);
    print('Deleting path: $path');
    await _firebaseStorage.ref(path).delete();
    print('Firebase Storage deletion successful');

    // Delete the product document from Firestore
    if (image != null) {
      print('Deleting Firestore product: $image');
      await _firestore.collection('Products').doc(image).delete(); // Delete the document
      print('Firestore product deletion successful');
    } else {
        print("Product image is null");
    }

    // Remove from local list
    _products.removeWhere((product) => product['image'] == imageUrl);

    _isLoading = false;
    notifyListeners();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product deleted successfully.")));

  } on FirebaseException catch (e) {
    _isLoading = false;
    notifyListeners();

    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Firebase error deleting product: ${e.message}")));
    print("Firebase error deleting product: ${e.message}");
  } catch (e) {
    _isLoading = false;
    notifyListeners();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An unexpected error occurred.")));
    print("Error deleting product: $e");
  }
}

  // Extract file path from Firebase Storage URL
  String extractPathFromUrl(String url) {
    Uri uri = Uri.parse(url);
    String encodedPath = uri.pathSegments.last;
    return Uri.decodeComponent(encodedPath);
  }

  // Upload image
  Future<String?> uploadImage(File imageFile, {String folder = 'products'}) async {
    _isUploading = true;
    notifyListeners();

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageReference = _firebaseStorage.ref().child('images/$folder/$fileName');

      UploadTask uploadTask = storageReference.putFile(imageFile);
      await uploadTask.whenComplete(() {});
      String imageUrl = await storageReference.getDownloadURL();

      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // Upload profile picture and save user ID and image path to Firestore
  Future<void> uploadProfilePicture(String userId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return; // User cancelled

    try {
      String fileName = "profile_${DateTime.now().millisecondsSinceEpoch}";
      Reference storageReference = _firebaseStorage.ref().child('images/profiles/$fileName');

      UploadTask uploadTask = storageReference.putFile(File(pickedFile.path));
      await uploadTask.whenComplete(() {});
      String imageUrl = await storageReference.getDownloadURL();

      // Save the user ID and image path to Firestore
      await _firestore.collection('users').doc(userId).set({
        'userId': userId,
        'profileImagePath': storageReference.fullPath, // Store the path, not the URL
      }, SetOptions(merge: true));

      _profileImageUrl = imageUrl;
      notifyListeners();
    } catch (e) {
      print("Error uploading profile picture: $e");
    }
  }

  // Fetch profile picture URL from Firestore
  Future<void> fetchProfilePicture(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        String? profileImagePath = userDoc['profileImagePath'];
        if (profileImagePath != null) {
          // Get the download URL from the stored path
          _profileImageUrl = await _firebaseStorage.ref(profileImagePath).getDownloadURL();
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error fetching profile picture: $e");
    }
  }
}