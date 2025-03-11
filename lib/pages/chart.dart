import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tjmarket/pages/chatscreen.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  Future<String?> _getProfileImageUrl(String? profileImagePath) async {
    if (profileImagePath == null || profileImagePath.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(profileImagePath).getDownloadURL();
    } catch (e) {
      print("Error fetching profile image: $e");
      return null;
    }
  }

  void _startChat(String receiverId, String receiverName) async {
    if (_currentUserId == null || receiverId == _currentUserId) return;

    List<String> chatIds = [_currentUserId!, receiverId];
    chatIds.sort();
    String chatId = chatIds.join("_");

    DocumentSnapshot chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [_currentUserId, receiverId],
        'lastMessage': '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          receiverId: receiverId,
          receiverName: receiverName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Available Users"), backgroundColor: Colors.blue[900]),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users available."));
          }

          List<DocumentSnapshot> users = snapshot.data!.docs.where((user) => user.id != _currentUserId).toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index];
              String username = user['username'] ?? 'Unknown User';
              String? profileImagePath = user['profileImagePath'];

              return FutureBuilder<String?>(
                future: _getProfileImageUrl(profileImagePath),
                builder: (context, imageSnapshot) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (imageSnapshot.connectionState == ConnectionState.done && imageSnapshot.data != null)
                          ? NetworkImage(imageSnapshot.data!)
                          : null,
                      child: (imageSnapshot.connectionState != ConnectionState.done || imageSnapshot.data == null)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(username),
                    subtitle: Text("Tap to chat"),
                    onTap: () => _startChat(user.id, username),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
