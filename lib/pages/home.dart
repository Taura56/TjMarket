import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tjmarket/Screens/form.dart';  
import 'package:tjmarket/pages/chart.dart';
import 'package:tjmarket/pages/chatscreen.dart';
import 'package:tjmarket/services/storage/storage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _isDarkMode = false;
  String? _userId;
  String _searchQuery = '';

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_userId != null) {
        _refreshData();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _fetchUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        !Provider.of<Storage>(context, listen: false).isLoading) {
      Provider.of<Storage>(context, listen: false).fetchImages();
    }
  }

  Future<void> _refreshData() async {
    if (_userId != null) {
      final storage = Provider.of<Storage>(context, listen: false);
      await storage.fetchImages();
      await storage.fetchProfilePicture(_userId!);
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_userId == null) return;
    final storage = Provider.of<Storage>(context, listen: false);
    await storage.uploadProfilePicture(_userId!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                _buildSellTodayContainer(),
                Expanded(child: _buildProductList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
  return Container(
    color: Colors.blue[900],
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
        IconButton(
          icon: const Icon(Icons.message, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatPage()),
            );
          },
        ),
        Expanded( 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0,vertical: 2.0),
            child: TextField(
              onChanged: _updateSearchQuery,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.white),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.blue[700],
              ),
            ),
          ),
        ),
        Switch(
          value: _isDarkMode,
          onChanged: (value) {
            setState(() {
              _isDarkMode = value;
            });
          },
        ),
      ],
    ),
  );
}

  Widget _buildSellTodayContainer() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            children: [
              Consumer<Storage>(
                builder: (context, storage, child) {
                  return GestureDetector(
                    onTap: _uploadProfileImage,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue,
                      backgroundImage: storage.profileImageUrl != null
                          ? NetworkImage(storage.profileImageUrl!)
                          : null,
                      child: storage.profileImageUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'What do you want to sell Today?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.photo_camera, color: Colors.blue),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProductForm()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
  return Consumer<Storage>(
    builder: (context, storage, child) {
      List<Map<String, dynamic>> filteredProducts = storage.products.where((product) {
        final productName = product['productName'].toString().toLowerCase();
        final category = product['category'].toString().toLowerCase();
        final description = product['description'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return productName.contains(query) || description.contains(query)|| category.contains(query);
      }).toList();

      return ListView.builder(
        controller: _scrollController,
        itemCount: filteredProducts.length + (storage.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredProducts.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildPostItem(filteredProducts[index]);
        },
      );
    },
  );
}

  Widget _buildPostItem(Map<String, dynamic> product) {
  final currentUser = FirebaseAuth.instance.currentUser; 
  final isCurrentUserPost = currentUser != null && currentUser.uid == product['userId'];
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blueAccent,
                  backgroundImage: product['profileImageUrl'] != null
                      ? NetworkImage(product['profileImageUrl'])
                      : null,
                  child: product['profileImageUrl'] == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  product['username'] ?? 'Unknown User',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                if (isCurrentUserPost) // Conditionally show the menu
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        Provider.of<Storage>(context, listen: false).deleteImage(
                          product['image'],
                          product['id'],
                          context,
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  )
                else
                  const Icon(Icons.more_horiz, color: Colors.grey), // Show icon, but no menu if not the user's post.
              ],
            ),
          ),
          Image.network(
            product['image'],
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.error, size: 50, color: Colors.red),
              );
            },
          ),
            Row(
              children: [
                Text('Message Seller',style: TextStyle(color:  _isDarkMode ? Colors.white : Colors.black,fontWeight: FontWeight.bold),),
                IconButton(
                  icon: Icon(Icons.message, color: _isDarkMode ? Colors.white : Colors.black),
                  onPressed: () {
                    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    String? sellerId = product['userId']; 
                    String? sellerName = product['username'];

                    if (currentUserId != null && sellerId != null && sellerId != currentUserId) {
                      List<String> chatIds = [currentUserId, sellerId];
                      chatIds.sort(); 
                      String chatId = chatIds.join("_");

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chatId,
                            receiverId: sellerId,
                            receiverName: sellerName ?? "Seller",
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Error: Unable to start chat.")),
                      );
                    }
                  },
                ),

              ],),
          
             Text(
                product['productName'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(height: 8.0,),
              Text(
                product['description'],
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(height: 8.0,),
              Text('PRICE: '
              'Ksh ${product['price'].toStringAsFixed(2)}',  
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
