import 'package:canteen_app/screens/user/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final cart = <String, int>{};
  final searchController = TextEditingController();
  String filterOption = "All"; // Options: "All", "Veg", "Non Veg"
  int cartCount = 0;
  double cartTotal = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMenuItems();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMenuItems() async {
    setState(() {
      isLoading = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      isLoading = false;
    });
  }

  void increaseQuantity(String itemId, double price) {
    setState(() {
      cart[itemId] = (cart[itemId] ?? 0) + 1;
      updateCartCountAndTotal();
    });
  }

  void decreaseQuantity(String itemId, double price) {
    setState(() {
      if (cart[itemId] != null && cart[itemId]! > 0) {
        cart[itemId] = cart[itemId]! - 1;
        if (cart[itemId] == 0) {
          cart.remove(itemId);
        }
        updateCartCountAndTotal();
      }
    });
  }
  
  void updateCartCountAndTotal() {
    cartCount = 0;
    cartTotal = 0.0;
    cart.forEach((id, qty) {
      cartCount += qty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuStream = FirebaseFirestore.instance.collection('menuItems').snapshots();

    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog when back button is pressed
        bool shouldPop = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Exit Menu"),
            content: const Text("Are you sure you want to go back to home?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // Don't pop
                child: const Text("CANCEL"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // Do pop
                child: const Text("YES"),
              ),
            ],
          ),
        ) ?? false; // Default to false if dialog is dismissed
        
        return shouldPop;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Menu",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFFFFB703),
          actions: [
            IconButton(
              icon: const Icon(Icons.track_changes, color: Colors.white),
              tooltip: "Track Order",
              onPressed: () {
                Navigator.pushNamed(context, '/track');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: "Logout",
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Logout"),
                    content: const Text("Are you sure you want to logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("CANCEL"),
                      ),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushReplacementNamed(context, '/auth');
                        },
                        child: const Text("LOGOUT"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar and filter row
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search food items",
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.filter_list, color: Color(0xFF023047)),
                      tooltip: "Filter",
                      onSelected: (String value) {
                        setState(() {
                          filterOption = value;
                        });
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'All',
                          child: Text('All Items'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'Veg',
                          child: Text('Vegetarian Only'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'Non Veg',
                          child: Text('Non-Vegetarian'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Filter indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Text(
                    "Filter: ",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB703),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      filterOption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Menu items list
            Expanded(
              child: isLoading 
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFB703),
                    ),
                  )
                : StreamBuilder(
                  stream: menuStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFB703),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No items available"));
                    }

                    final items = snapshot.data!.docs;
                    
                    // Filter items based on search text and veg/non-veg filter.
                    final filteredItems = items.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? "").toString().toLowerCase();
                      final searchText = searchController.text.toLowerCase();
                      bool matchesSearch = name.contains(searchText);

                      // Check the veg filter
                      bool matchesFilter = true;
                      if (filterOption == "Veg") {
                        matchesFilter = data['isVeg'] == true;
                      } else if (filterOption == "Non Veg") {
                        matchesFilter = data['isVeg'] == false;
                      }
                      
                      return matchesSearch && matchesFilter;
                    }).toList();

                    if (filteredItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 50, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text("No matching items"),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  searchController.clear();
                                  filterOption = "All";
                                });
                              },
                              child: const Text("Clear filters"),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final doc = filteredItems[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final id = doc.id;
                        final price = (data['price'] ?? 0.0) is double 
                          ? (data['price'] ?? 0.0) 
                          : double.parse((data['price'] ?? '0').toString());
                        int quantity = cart[id] ?? 0;
                        bool isVeg = data['isVeg'] ?? false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Food Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: data['imageUrl'] != null
                                    ? Image.network(
                                        data['imageUrl'],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.restaurant, size: 40),
                                        ),
                                      )
                                    : Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.restaurant, size: 40),
                                      ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Food details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Veg/Non-veg indicator
                                          Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isVeg ? Colors.green : Colors.red,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: isVeg ? Colors.green : Colors.red,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // Item name
                                          Expanded(
                                            child: Text(
                                              data['name'] ?? 'Food Item',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 4),
                                      
                                      // Description if available
                                      if (data['description'] != null)
                                        Text(
                                          data['description'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        
                                      const SizedBox(height: 8),
                                      
                                      // Price and add to cart row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "₹${price.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFFB703),
                                            ),
                                          ),
                                          
                                          // Add/Remove buttons
                                          quantity > 0 
                                            ? Row(
                                                children: [
                                                  IconButton(
                                                    onPressed: () => decreaseQuantity(id, price),
                                                    icon: const Icon(Icons.remove_circle_outline),
                                                    color: const Color(0xFFFFB703),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFB703).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      quantity.toString(),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () => increaseQuantity(id, price),
                                                    icon: const Icon(Icons.add_circle_outline),
                                                    color: const Color(0xFFFFB703),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : ElevatedButton(
                                                onPressed: () => increaseQuantity(id, price),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFFFB703),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                  minimumSize: const Size(40, 30),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                ),
                                                child: const Text("ADD"),
                                              ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // Using MaterialPageRoute instead of named route for better control
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CartScreen(
                  cart: cart,
                  // This callback will be called whenever cart changes in CartScreen
                  onCartUpdated: () {
                    // Update UI in MenuScreen when cart changes
                    setState(() {
                      updateCartCountAndTotal();
                    });
                  },
                ),
              ),
            );
          },
          backgroundColor: const Color(0xFF023047),
          icon: Stack(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
              if (cartCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB703),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: Text(
            cartCount > 0 ? "View Cart" : "Cart Empty",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}