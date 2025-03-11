import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tjmarket/Screens/form.dart';  // Correct Chat Page
import 'package:tjmarket/pages/chart.dart';
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
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
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
        return ListView.builder(
          controller: _scrollController,
          itemCount: storage.products.length + (storage.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == storage.products.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildPostItem(storage.products[index]);
          },
        );
      },
    );
  }

  Widget _buildPostItem(Map<String, dynamic> product) {
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
                  const Icon(Icons.more_horiz, color: Colors.grey),
                ],
              ),
            ),
            Image.network(
              product['image'],
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                    child: Icon(Icons.error, size: 50, color: Colors.red));
              },
            ),
             Text(
            product['productName'],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
              Text(
              '\$${product['price'].toStringAsFixed(2)}',  // Format as currency
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
