import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminOrderHistoryScreen extends StatefulWidget {
  const AdminOrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AdminOrderHistoryScreen> createState() => _AdminOrderHistoryScreenState();
}

class _AdminOrderHistoryScreenState extends State<AdminOrderHistoryScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Today', 'This Week', 'This Month'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> getOrderHistoryStream() {
    Query query = FirebaseFirestore.instance.collection('orders');
    
    // Apply date filters
    if (_selectedFilter != 'All') {
      final now = DateTime.now();
      DateTime startDate;
      
      switch (_selectedFilter) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'This Week':
          // Start from last 7 days
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'This Month':
          // Start from beginning of current month
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(2000); // Fallback to a very old date
      }
      
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    
    return query.orderBy('timestamp', descending: true).snapshots();
  }

  Future<String> fetchUserEmail(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['email'] ?? 'Unknown Email';
      }
    } catch (e) {
      print('Error fetching user email: $e');
    }
    return 'Unknown Email';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by order ID or item name',
                    hintStyle: GoogleFonts.poppins(color: Colors.white70),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  style: GoogleFonts.poppins(color: Colors.white),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Filter chips
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filterOptions.length,
                    itemBuilder: (context, index) {
                      final filter = _filterOptions[index];
                      final isSelected = filter == _selectedFilter;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            filter,
                            style: GoogleFonts.poppins(
                              color: isSelected ? const Color(0xFFFFB703) : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          backgroundColor: Colors.white.withOpacity(0.2),
                          selectedColor: Colors.white,
                          checkmarkColor: const Color(0xFFFFB703),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Orders List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getOrderHistoryStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading order history',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703)));
                }

                final allOrders = snapshot.data!.docs;
                
                // Filter orders based on search query
                final filteredOrders = allOrders.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  
                  final data = doc.data() as Map<String, dynamic>;
                  final orderId = doc.id.toLowerCase();
                  
                  // Search in items - FIXED to handle List format
                  final itemsData = data['items'];
                  String itemsText = '';
                  
                  if (itemsData != null) {
                    if (itemsData is List<dynamic>) {
                      // Handle new List format
                      for (var item in itemsData) {
                        if (item is Map<String, dynamic>) {
                          itemsText += (item['name'] ?? '').toString().toLowerCase() + ' ';
                        }
                      }
                    } else if (itemsData is Map<String, dynamic>) {
                      // Handle old Map format
                      itemsText = itemsData.keys.join(' ').toLowerCase();
                    }
                  }
                  
                  return orderId.contains(_searchQuery) || itemsText.contains(_searchQuery);
                }).toList();

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.history,
                          size: 72,
                          color: Color(0xFFDDDDDD),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No orders found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try a different search term'
                              : 'Orders will appear here when placed',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final doc = filteredOrders[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // FIXED: Process items data to handle List format
                    final itemsData = data['items'];
                    final List<Map<String, dynamic>> orderItems = [];
                    String itemsDisplayText = '';
                    
                    if (itemsData != null) {
                      if (itemsData is List<dynamic>) {
                        // Handle new List format from cart_screen.dart
                        for (var item in itemsData) {
                          if (item is Map<String, dynamic>) {
                            orderItems.add({
                              'name': item['name'] ?? 'Unknown Item',
                              'quantity': item['quantity'] ?? 1,
                              'price': item['price'] ?? 0.0,
                              'subtotal': item['subtotal'] ?? 0.0,
                            });
                          }
                        }
                        itemsDisplayText = orderItems.map((item) => '${item['name']} × ${item['quantity']}').join(', ');
                      } else if (itemsData is Map<String, dynamic>) {
                        // Handle old Map format (for backward compatibility)
                        itemsData.forEach((key, value) {
                          orderItems.add({
                            'name': key,
                            'quantity': value is int ? value : (int.tryParse(value.toString()) ?? 1),
                            'price': 0.0,
                            'subtotal': 0.0,
                          });
                        });
                        itemsDisplayText = itemsData.entries.map((e) => '${e.key} × ${e.value}').join(', ');
                      }
                    }
                    
                    final status = data['status'] ?? 'Unknown';
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                    final total = data['total'] ?? 0.0;
                    final userId = data['userId'] ?? '';

                    return FutureBuilder<String>(
                      future: fetchUserEmail(userId),
                      builder: (context, emailSnapshot) {
                        final email = emailSnapshot.data ?? 'Loading...';
                        
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.all(16),
                            title: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatusIndicator(status),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Order ID and Total on separate lines to prevent overflow
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Order #${doc.id.substring(0, 6)}',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Total amount in a colored container
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB703).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '₹${total.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: const Color(0xFFFFB703),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Customer email
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              email,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Timestamp
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              timestamp != null
                                                  ? _formatDateTime(timestamp)
                                                  : 'Unknown time',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Items:',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // IMPROVED: Display items with better formatting
                                    if (orderItems.isNotEmpty)
                                      ...orderItems.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFB703).withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.restaurant,
                                                  size: 12,
                                                  color: Color(0xFFFFB703),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['name'] ?? 'Unknown Item',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'Qty: ${item['quantity']}',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 11,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                        if (item['price'] != null && item['price'] > 0) ...[
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            '₹${item['price'].toStringAsFixed(2)} each',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 11,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (item['subtotal'] != null && item['subtotal'] > 0)
                                                Text(
                                                  '₹${item['subtotal'].toStringAsFixed(2)}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFFFFB703),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList()
                                    else
                                      Text(
                                        itemsDisplayText.isNotEmpty ? itemsDisplayText : 'No items',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                        ),
                                      ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Status and Order ID with proper styling
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Status with colored background
                                        Row(
                                          children: [
                                            Text(
                                              'Status: ',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(status).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: _getStatusColor(status),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Order ID with subtle background
                                        Row(
                                          children: [
                                            Text(
                                              'Order ID: ',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  doc.id,
                                                  style: GoogleFonts.robotoMono(
                                                    fontSize: 12,
                                                    color: Colors.grey[700],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'placed':
        color = Colors.blue;
        icon = Icons.receipt_outlined;
        break;
      case 'cooking':
        color = Colors.orange;
        icon = Icons.soup_kitchen_outlined;
        break;
      case 'cooked':
        color = Colors.green;
        icon = Icons.restaurant_outlined;
        break;
      case 'ready to pickup':
        color = Colors.purple;
        icon = Icons.takeout_dining_outlined;
        break;
      case 'completed':
        color = Colors.teal;
        icon = Icons.check_circle_outline;
        break;
      case 'terminated':
        color = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.blue;
      case 'cooking':
        return Colors.orange;
      case 'cooked':
        return Colors.green;
      case 'ready to pickup':
        return Colors.purple;
      case 'completed':
        return Colors.teal;
      case 'terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  // Helper method to format date time
  String _formatDateTime(DateTime dateTime) {
    // Format date as DD/MM/YYYY
    final date = '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    
    // Format time as HH:MM
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    return '$date, $time';
  }
}