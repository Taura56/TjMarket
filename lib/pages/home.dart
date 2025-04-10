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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _isDarkMode = false;
  String? _userId;
  String _searchQuery = '';

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    await Provider.of<Storage>(context, listen: false).uploadProfilePicture(_userId!);
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _navigateToProductForm() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductForm()));
  }

  void _navigateToChatPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage()));
  }

  void _toggleDarkMode(bool value) {
    setState(() => _isDarkMode = value);
  }

  void _openChatWithSeller(String sellerId, String sellerName) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && sellerId != user.uid) {
      final chatId = [user.uid, sellerId]..sort();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId.join('_'),
            receiverId: sellerId,
            receiverName: sellerName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
        children: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
          IconButton(
            icon: const Icon(Icons.message, color: Colors.white),
            onPressed: _navigateToChatPage,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextField(
                onChanged: _updateSearchQuery,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(color: Colors.white),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
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
            onChanged: _toggleDarkMode,
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
                  'What do you want to sell today?', 
                  style: TextStyle(fontWeight: FontWeight.bold)
                ),
              ),
              IconButton(
                icon: const Icon(Icons.photo_camera, color: Colors.blue),
                onPressed: _navigateToProductForm,
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
        final filtered = storage.products.where((product) {
          final query = _searchQuery.toLowerCase();
          return (product['productName'] ?? '').toLowerCase().contains(query) ||
                 (product['description'] ?? '').toLowerCase().contains(query) ||
                 (product['category'] ?? '').toLowerCase().contains(query);
        }).toList();

        if (filtered.isEmpty && !storage.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty 
                      ? 'No products available' 
                      : 'No products match your search',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: filtered.length + (storage.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == filtered.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return _buildPostItem(filtered[index]);
          },
        );
      },
    );
  }

  Widget _buildPostItem(Map<String, dynamic> product) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUserPost = currentUser?.uid == product['userId'];

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
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                backgroundImage: product['profileImageUrl'] != null
                    ? NetworkImage(product['profileImageUrl'])
                    : null,
                child: product['profileImageUrl'] == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              title: Text(
                product['username'] ?? 'Unknown User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Category: ${product['category'] ?? 'Uncategorized'}',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey[300] : Colors.grey[600],
                ),
              ),
              trailing: isCurrentUserPost
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          Provider.of<Storage>(context, listen: false).deleteImage(
                            product['image'],
                            product['id'],
                            context,
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'delete', child: Text('Delete Sold Product')),
                      ],
                    )
                  : null,
            ),
            GestureDetector(
              onTap: () {
                // Show full image or product details
              },
              child: Image.network(
                product['image'],
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.error_outline, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product['productName'] ?? 'Unnamed Product',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Ksh ${product['price'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product['description'] ?? 'No description available',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isCurrentUserPost)
                    ElevatedButton.icon(
                      onPressed: () {
                        _openChatWithSeller(
                          product['userId'],
                          product['username'] ?? 'Seller',
                        );
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('Message Seller'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}