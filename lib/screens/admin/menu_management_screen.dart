// lib/screens/admin/menu_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({Key? key}) : super(key: key);

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> with TickerProviderStateMixin {
  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  
  // Form state
  bool showAddForm = false;
  bool showEditForm = false;
  bool isVeg = true;
  bool isUploading = false;
  bool hasUnlimitedStock = false;
  File? _selectedImage;
  String? _editingItemId;
  
  // Animation controllers
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  
  // Image picker
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.elasticOut,
    ));
    
    _fadeController!.forward();
    _slideController!.forward();
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    _fadeController?.dispose();
    _slideController?.dispose();
    super.dispose();
  }

  // Image picker method
  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Error selecting image: $e', Colors.red);
    }
  }

  // Upload image to Firebase Storage - FIXED VERSION
  Future<String?> uploadImage(File imageFile) async {
    try {
      final String fileName = 'menu_items/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      
      // Add metadata for better handling
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded_by': 'admin',
          'upload_time': DateTime.now().toIso8601String(),
        },
      );
      
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
      
      // Monitor upload progress (optional)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print('Upload progress: ${(snapshot.bytesTransferred / snapshot.totalBytes * 100).round()}%');
      });
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      _showSnackBar('Failed to upload image: $e', Colors.red);
      return null;
    }
  }

  // Show snackbar helper
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Add new menu item - FIXED VERSION
  Future<void> addMenuItem() async {
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    final description = descriptionController.text.trim();
    final quantity = hasUnlimitedStock ? -1 : (int.tryParse(quantityController.text.trim()) ?? 0);
    
    if (name.isEmpty || price <= 0) {
      _showSnackBar('Please enter a valid name and price', Colors.red);
      return;
    }

    if (!hasUnlimitedStock && quantity <= 0) {
      _showSnackBar('Please enter a valid quantity or mark as unlimited', Colors.red);
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      String imageUrl = "";
      
      // Upload image if selected
      if (_selectedImage != null) {
        print('Starting image upload...');
        final url = await uploadImage(_selectedImage!);
        if (url != null) {
          imageUrl = url;
          print('Image upload completed: $imageUrl');
        } else {
          print('Image upload failed');
          // Continue without image rather than failing completely
        }
      }

      print('Adding menu item to Firestore...');
      
      // Add to Firestore
      final docRef = await FirebaseFirestore.instance.collection('menuItems').add({
        'name': name,
        'price': price,
        'description': description,
        'imageUrl': imageUrl,
        'available': true,
        'isVeg': isVeg,
        'quantity': quantity,
        'hasUnlimitedStock': hasUnlimitedStock,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Menu item added successfully with ID: ${docRef.id}');
      
      // Reset form and show success
      resetForm();
      _showSnackBar('$name added successfully!', Colors.green);
      
    } catch (e) {
      print('Error adding menu item: $e');
      _showSnackBar('Error adding item: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  // Edit menu item - FIXED VERSION
  Future<void> editMenuItem() async {
    if (_editingItemId == null) return;
    
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    final description = descriptionController.text.trim();
    final quantity = hasUnlimitedStock ? -1 : (int.tryParse(quantityController.text.trim()) ?? 0);
    
    if (name.isEmpty || price <= 0) {
      _showSnackBar('Please enter a valid name and price', Colors.red);
      return;
    }

    if (!hasUnlimitedStock && quantity < 0) {
      _showSnackBar('Please enter a valid quantity or mark as unlimited', Colors.red);
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      Map<String, dynamic> updateData = {
        'name': name,
        'price': price,
        'description': description,
        'isVeg': isVeg,
        'quantity': quantity,
        'hasUnlimitedStock': hasUnlimitedStock,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Upload new image if selected
      if (_selectedImage != null) {
        print('Uploading new image for edit...');
        final url = await uploadImage(_selectedImage!);
        if (url != null) {
          updateData['imageUrl'] = url;
          print('New image uploaded: $url');
        }
      }

      await FirebaseFirestore.instance
          .collection('menuItems')
          .doc(_editingItemId)
          .update(updateData);

      print('Menu item updated successfully');
      resetForm();
      _showSnackBar('$name updated successfully!', Colors.green);
    } catch (e) {
      print('Error updating menu item: $e');
      _showSnackBar('Error updating item: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  // Load item data for editing
  void loadItemForEdit(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    setState(() {
      _editingItemId = doc.id;
      nameController.text = data['name'] ?? '';
      priceController.text = (data['price'] ?? 0).toString();
      descriptionController.text = data['description'] ?? '';
      isVeg = data['isVeg'] ?? true;
      hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
      
      if (hasUnlimitedStock) {
        quantityController.text = '';
      } else {
        final quantity = data['quantity'] ?? 0;
        quantityController.text = quantity.toString();
      }
      
      _selectedImage = null;
      showEditForm = true;
      showAddForm = false;
    });
  }

  // Reset form fields
  void resetForm() {
    setState(() {
      nameController.clear();
      priceController.clear();
      descriptionController.clear();
      quantityController.clear();
      isVeg = true;
      hasUnlimitedStock = false;
      _selectedImage = null;
      showAddForm = false;
      showEditForm = false;
      _editingItemId = null;
      isUploading = false;
    });
  }

  // Delete a menu item
  Future<void> deleteItem(String docId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Item',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$itemName"?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('DELETE', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('menuItems').doc(docId).delete();
      _showSnackBar('$itemName deleted successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Error deleting item: $e', Colors.red);
    }
  }

  // Toggle the availability of a menu item
  Future<void> toggleAvailability(String docId, bool current, String itemName) async {
    try {
      await FirebaseFirestore.instance
          .collection('menuItems')
          .doc(docId)
          .update({'available': !current});
          
      _showSnackBar(
        current ? '$itemName marked as unavailable' : '$itemName marked as available',
        Colors.green,
      );
    } catch (e) {
      _showSnackBar('Error updating availability: $e', Colors.red);
    }
  }

  // Update stock quantity
  Future<void> _updateStock(String docId, int newQuantity) async {
    try {
      await FirebaseFirestore.instance
          .collection('menuItems')
          .doc(docId)
          .update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showSnackBar('Error updating stock: $e', Colors.red);
    }
  }

  // Get stock status widget
  Widget getStockStatusWidget(int quantity, bool hasUnlimitedStock) {
    if (hasUnlimitedStock) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.all_inclusive, size: 16, color: Colors.blue),
            SizedBox(width: 4),
            Text(
              'Unlimited',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else if (quantity <= 0) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
            SizedBox(width: 4),
            Text(
              'Out of Stock',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else if (quantity <= 5) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 16, color: Colors.orange),
            SizedBox(width: 4),
            Text(
              'Low Stock ($quantity)',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
            SizedBox(width: 4),
            Text(
              'In Stock ($quantity)',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          showEditForm ? "Edit Menu Item" : (showAddForm ? "Add Menu Item" : "Menu Management"),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: (showAddForm || showEditForm) 
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: resetForm,
            )
          : null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFB703), Color(0xFFFFC107)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: (showAddForm || showEditForm)
            ? _buildItemForm()
            : _buildMenuList(),
        ),
      ),
      floatingActionButton: (!showAddForm && !showEditForm) 
        ? (_fadeAnimation != null 
            ? FadeTransition(
                opacity: _fadeAnimation!,
                child: FloatingActionButton.extended(
                  onPressed: () {
                    setState(() {
                      showAddForm = true;
                    });
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFFB703),
                  icon: Icon(Icons.add),
                  label: Text(
                    "Add Menu Item",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  elevation: 8,
                ),
              )
            : FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    showAddForm = true;
                  });
                },
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFFB703),
                icon: Icon(Icons.add),
                label: Text(
                  "Add Menu Item",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                elevation: 8,
              ))
        : null,
    );
  }

  Widget _buildItemForm() {
    if (_fadeAnimation == null || _slideAnimation == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildFormContent(),
              ),
            ),
          ),
        ),
      );
    }
    
    return FadeTransition(
      opacity: _fadeAnimation!,
      child: SlideTransition(
        position: _slideAnimation!,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildFormContent(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB703).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                showEditForm ? Icons.edit : Icons.add_business,
                color: const Color(0xFFFFB703),
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showEditForm ? "Edit Item" : "Add New Item",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    showEditForm ? "Update menu item details" : "Create a new menu item",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        
        // Basic Information Section
        _buildSectionHeader("Basic Information", Icons.info_outline),
        const SizedBox(height: 16),
        
        // Name field
        _buildTextField(
          controller: nameController,
          label: "Item Name",
          hint: "Enter food item name",
          icon: Icons.fastfood,
          required: true,
        ),
        const SizedBox(height: 16),
        
        // Price and Type Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: priceController,
                label: "Price (₹)",
                hint: "0.00",
                icon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
                required: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildVegToggle(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Stock Management Section
        _buildSectionHeader("Stock Management", Icons.inventory_2),
        const SizedBox(height: 16),
        
        _buildStockSection(),
        const SizedBox(height: 24),
        
        // Description Section
        _buildSectionHeader("Description", Icons.description),
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: descriptionController,
          label: "Description",
          hint: "Enter item description (optional)",
          icon: Icons.notes,
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        
        // Image Section
        _buildSectionHeader("Image", Icons.photo_camera),
        const SizedBox(height: 16),
        
        _buildImageSelector(),
        const SizedBox(height: 30),
        
        // Action buttons
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFB703), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(),
        decoration: InputDecoration(
          labelText: "$label${required ? ' *' : ''}",
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFFFFB703)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: const Color(0xFFFFB703), width: 2),
          ),
          labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
          hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildVegToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Type",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVeg ? "Veg" : "Non-Veg",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isVeg ? Colors.green : Colors.red,
                ),
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
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: hasUnlimitedStock,
                onChanged: (value) {
                  setState(() {
                    hasUnlimitedStock = value ?? false;
                    if (hasUnlimitedStock) {
                      quantityController.clear();
                    }
                  });
                },
                activeColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: Text(
                  "Unlimited Stock",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          
          if (!hasUnlimitedStock) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: quantityController,
              label: "Available Quantity",
              hint: "Enter stock quantity",
              icon: Icons.inventory,
              keyboardType: TextInputType.number,
              required: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSelector() {
    return GestureDetector(
      onTap: pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
        ),
        child: _selectedImage == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB703).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 40,
                    color: const Color(0xFFFFB703),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Tap to add image",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  "Upload food item photo",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(
                    _selectedImage!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isUploading ? null : resetForm,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: isUploading 
              ? null 
              : (showEditForm ? editMenuItem : addMenuItem),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 8,
              shadowColor: const Color(0xFFFFB703).withOpacity(0.4),
            ),
            child: isUploading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      showEditForm ? "Updating..." : "Adding...",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(showEditForm ? Icons.update : Icons.add),
                    const SizedBox(width: 8),
                    Text(
                      showEditForm ? "Update Item" : "Add Item",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuList() {
    if (_fadeAnimation == null) {
      return Container(
        margin: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: _buildMenuListContent(),
            ),
          ),
        ),
      );
    }
    
    return FadeTransition(
      opacity: _fadeAnimation!,
      child: Container(
        margin: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: _buildMenuListContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuListContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB703).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: const Color(0xFFFFB703),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Menu Items",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "Manage your restaurant menu",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Menu Items List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
              .collection('menuItems')
              .orderBy('name')
              .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Error loading menu items",
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${snapshot.error}",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFFFB703),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Loading menu items...",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              final items = snapshot.data?.docs ?? [];
              
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "No menu items yet",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Start by adding your first menu item",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            showAddForm = true;
                          });
                        },
                        icon: Icon(Icons.add),
                        label: Text(
                          "Add Your First Item",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB703),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
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
                  final quantity = data['quantity'] ?? 0;
                  final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
                  
                  // Determine if item should be grayed out (out of stock)
                  final isOutOfStock = !hasUnlimitedStock && quantity <= 0;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isOutOfStock ? Colors.grey.withOpacity(0.3) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image section
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            Stack(
                              children: [
                                ColorFiltered(
                                  colorFilter: isOutOfStock 
                                    ? ColorFilter.mode(Colors.grey, BlendMode.saturation)
                                    : ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                  child: Image.network(
                                    imageUrl,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, _) {
                                      return Container(
                                        height: 180,
                                        color: Colors.grey[200],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_not_supported,
                                              size: 50,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Image not available",
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (isOutOfStock)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(25),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'OUT OF STOCK',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          
                          // Content section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title row with veg indicator and stock status
                                Row(
                                  children: [
                                    // Veg/non-veg indicator
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isVeg ? Colors.green : Colors.red,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isVeg ? Colors.green : Colors.red,
                                          shape: isVeg ? BoxShape.rectangle : BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Item name
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isOutOfStock ? Colors.grey[600] : Colors.black87,
                                          decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    
                                    // Stock status badge
                                    getStockStatusWidget(quantity, hasUnlimitedStock),
                                  ],
                                ),
                                
                                if (description != null && description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: isOutOfStock ? Colors.grey[500] : Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                
                                const SizedBox(height: 16),
                                
                                // Price and actions row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Price
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock 
                                          ? Colors.grey.withOpacity(0.2)
                                          : const Color(0xFFFFB703).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "₹${price.toStringAsFixed(2)}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isOutOfStock ? Colors.grey[500] : const Color(0xFFFFB703),
                                          decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    
                                    // Action buttons
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Edit button
                                        _buildActionButton(
                                          icon: Icons.edit,
                                          color: Colors.blue,
                                          onTap: () => loadItemForEdit(doc),
                                          tooltip: "Edit item",
                                        ),
                                        const SizedBox(width: 8),
                                        
                                        // Availability toggle
                                        _buildActionButton(
                                          icon: available ? Icons.visibility_off : Icons.visibility,
                                          color: available ? Colors.orange : Colors.green,
                                          onTap: () => toggleAvailability(doc.id, available, name),
                                          tooltip: available ? "Mark unavailable" : "Mark available",
                                        ),
                                        const SizedBox(width: 8),
                                        
                                        // Delete button
                                        _buildActionButton(
                                          icon: Icons.delete,
                                          color: Colors.red,
                                          onTap: () => deleteItem(doc.id, name),
                                          tooltip: "Delete item",
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                // Status and quick actions
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Availability status
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: available 
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: available ? Colors.green : Colors.red,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            available ? Icons.check_circle : Icons.cancel,
                                            size: 16,
                                            color: available ? Colors.green : Colors.red,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            available ? 'Available' : 'Hidden',
                                            style: GoogleFonts.poppins(
                                              color: available ? Colors.green : Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Quick stock update buttons
                                    if (!hasUnlimitedStock)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (quantity > 0)
                                            _buildStockButton(
                                              icon: Icons.remove,
                                              color: Colors.red,
                                              onTap: () => _updateStock(doc.id, quantity - 1),
                                            ),
                                          if (quantity > 0) SizedBox(width: 8),
                                          _buildStockButton(
                                            icon: Icons.add,
                                            color: Colors.green,
                                            onTap: () => _updateStock(doc.id, quantity + 1),
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
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildStockButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      ),
    );
  }
}