import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();
  bool isVeg = true;
  File? _selectedImage;
  bool isUploading = false;
  bool showAddForm = false;

  // Pick an image from the gallery
  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 80,
        maxWidth: 800,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting image: $e")),
      );
    }
  }

  // Upload the image to Firebase Storage
  Future<String?> uploadImage(File imageFile) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef = FirebaseStorage.instance.ref().child('menuImages/$fileName');
      
      // Upload file with metadata
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Wait for completion
      final snapshot = await uploadTask;
      
      // Get download URL
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  // Add a new menu item
  Future<void> addMenuItem() async {
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    final description = descriptionController.text.trim();
    
    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid name and price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      String imageUrl = "";
      if (_selectedImage != null) {
        final url = await uploadImage(_selectedImage!);
        if (url != null) {
          imageUrl = url;
        }
      }

      await FirebaseFirestore.instance.collection('menuItems').add({
        'name': name,
        'price': price,
        'description': description,
        'imageUrl': imageUrl,
        'available': true,
        'isVeg': isVeg,
        'createdAt': FieldValue.serverTimestamp(),
      });

      resetForm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  // Reset form fields
  void resetForm() {
    setState(() {
      nameController.clear();
      priceController.clear();
      descriptionController.clear();
      isVeg = true;
      _selectedImage = null;
      showAddForm = false;
    });
  }

  // Delete a menu item
  Future<void> deleteItem(String docId, String itemName) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('DELETE'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('menuItems').doc(docId).delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$itemName deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Toggle the availability of a menu item
  Future<void> toggleAvailability(String docId, bool current, String itemName) async {
    try {
      await FirebaseFirestore.instance
          .collection('menuItems')
          .doc(docId)
          .update({'available': !current});
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(current 
            ? '$itemName marked as unavailable' 
            : '$itemName marked as available'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating availability: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Menu Management",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
        elevation: 4,
      ),
      floatingActionButton: !showAddForm ? FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            showAddForm = true;
          });
        },
        backgroundColor: const Color(0xFFFFB703),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text("Add Menu Item"),
      ) : null,
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        child: showAddForm 
          ? _buildAddItemForm() // Show only the form when adding
          : StreamBuilder<QuerySnapshot>( // Show only the list when not adding
                stream: FirebaseFirestore.instance
                  .collection('menuItems')
                  .orderBy('name')
                  .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error loading menu items",
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFFB703)),
                    );
                  }
                  
                  final items = snapshot.data?.docs ?? [];
                  
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No items in the menu yet",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                showAddForm = true;
                              });
                            },
                            icon: Icon(Icons.add),
                            label: Text("Add Your First Item"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB703),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final doc = items[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      // Get item details
                      final name = data['name'] ?? 'Unnamed Item';
                      var price = 0.0;
                      if (data['price'] != null) {
                        if (data['price'] is num) {
                          price = (data['price'] as num).toDouble();
                        } else {
                          price = double.tryParse(data['price'].toString()) ?? 0.0;
                        }
                      }
                      
                      final available = data['available'] ?? true;
                      final isVeg = data['isVeg'] ?? false;
                      final imageUrl = data['imageUrl'] as String?;
                      final description = data['description'] as String?;
                      
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            // Optionally handle tap for detailed view or edit
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image (if available)
                              if (imageUrl != null && imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, _) {
                                      print("Image error: $error");
                                      return Container(
                                        height: 120,
                                        color: Colors.grey[300],
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 50,
                                          color: Colors.grey[500],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              
                              // Item details
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title row with veg/non-veg indicator
                                    Row(
                                      children: [
                                        // Veg/non-veg indicator
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isVeg ? Colors.green : Colors.red,
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: isVeg ? Colors.green : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        
                                        // Item name
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        
                                        // Price
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFB703),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "₹${price.toStringAsFixed(2)}",
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Description (if available)
                                    if (description != null && description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          description,
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[700],
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      
                                    const SizedBox(height: 12),
                                    
                                    // Action buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Availability badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: available ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: available ? Colors.green : Colors.red,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            available ? "Available" : "Unavailable",
                                            style: GoogleFonts.poppins(
                                              color: available ? Colors.green : Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        
                                        // Actions
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () => toggleAvailability(doc.id, available, name),
                                              icon: Icon(
                                                available ? Icons.visibility_off : Icons.visibility,
                                                color: available ? Colors.grey[600] : const Color(0xFFFFB703),
                                              ),
                                              tooltip: available ? "Mark unavailable" : "Mark available",
                                            ),
                                            IconButton(
                                              onPressed: () => deleteItem(doc.id, name),
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              tooltip: "Delete item",
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
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
  
  Widget _buildAddItemForm() {
    return Scaffold(
      
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Item Name *",
                      prefixIcon: const Icon(Icons.fastfood),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Price field and Veg/Non-veg toggle
                  Row(
                    children: [
                      // Price field
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Price (₹) *",
                            prefixIcon: const Icon(Icons.currency_rupee),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Veg/Non-veg toggle
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Veg",
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            Switch(
                              value: isVeg,
                              onChanged: (value) {
                                setState(() {
                                  isVeg = value;
                                });
                              },
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Description field
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Description (Optional)",
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Image selector
                  Center(
                    child: _selectedImage == null
                      ? OutlinedButton.icon(
                          onPressed: pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text("Upload Image (Optional)"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFB703),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        )
                      : Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: pickImage,
                              icon: const Icon(Icons.edit),
                              label: const Text("Change Image"),
                            ),
                          ],
                        ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Add button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isUploading ? null : addMenuItem,
                      icon: isUploading 
                        ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(Icons.add),
                      label: Text(
                        isUploading ? "Adding..." : "Add to Menu",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB703),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}