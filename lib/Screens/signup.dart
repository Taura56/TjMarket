import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tjmarket/Screens/login.dart';

class SignupForm extends StatefulWidget {
  @override
  _SignupFormState createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Store user data in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'created_at': Timestamp.now(),
      });

      // Navigate to HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginForm()),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'email-already-in-use') {
        message = 'This email is already in use.';
      } else if (e.code == 'weak-password') {
        message = 'Password should be at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format.';
      } else {
        message = 'Signup failed: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.blue[900],
      appBar: AppBar(title: Text('Sign Up Page')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100), 
                child:  Image.asset(
                'assets/icon/icon.png', 
                height: 200, 
              ),
              ),
              SizedBox(height: 20,),
              TextFormField(
                controller: _usernameController,
                style: TextStyle(color: Colors.white), 
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.blue[700],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  errorStyle: TextStyle(color: Colors.red),
                  ),
                validator: (value) => value!.trim().isEmpty ? 'Enter username' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                style: TextStyle(color: Colors.white), 
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.blue[700],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  errorStyle: TextStyle(color: Colors.red),
                  ),
                validator: (value) => value!.trim().isEmpty ? 'Enter email' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                style: TextStyle(color: Colors.white), 
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.blue[700],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  errorStyle: TextStyle(
                    color: Colors.red[500],
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold, // Example: bold font weight
                  ),
                  ),
                obscureText: true,
                validator: (value) =>
                    value!.trim().length < 8 ? 'Password must be at least 8 characters' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _confirmPasswordController,
                style: TextStyle(color: Colors.white), 
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.blue[700],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  errorStyle: TextStyle(
                    color: Colors.red[500],
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold, // Example: bold font weight
                  ),
                  ),
                obscureText: true,
                validator: (value) =>
                    value != _passwordController.text ? 'Passwords do not match' : null,
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _signup,
                      child: Text('Sign Up',style: TextStyle(color: Colors.black,fontSize: 20.0,),),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Already have an account? Log in',style: TextStyle(color: Colors.white,fontSize: 18.0,),),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
