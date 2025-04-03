import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tjmarket/services/storage/storage.dart';
import 'dart:io';

class ProductForm extends StatefulWidget {
  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _category = 'Electronics';
  bool _isLoading = false;
  File? _image;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select an image')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = Provider.of<Storage>(context, listen: false);
      String? imageUrl = await storage.uploadImage(_image!);
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('Products').add({
        'productName': _nameController.text,
        'description': _descriptionController.text,
        'price': double.parse(_priceController.text),
        'category': _category,
        'userId': user?.uid,
        'image': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product added successfully!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      appBar: AppBar(title: Text('Add Product')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _image == null
                      ? Icon(Icons.add_a_photo, size: 100, color: Colors.black)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        ),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                validator: (value) => value!.isEmpty ? 'Enter product name' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price',
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Enter price' : null,
              ),
              SizedBox(height: 10),
              DropdownButtonFormField(
                value: _category,
                items: ['Electronics', 'Clothing', 'Home & Kitchen', 'Toys']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (value) => setState(() => _category = value.toString()),
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Product Description',
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                validator: (value) => value!.isEmpty ? 'Describe your product' : null,
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _uploadProduct,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        backgroundColor: Colors.white,
                      ),
                      child: Text('Submit Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
