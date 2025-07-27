// lib/screens/admin/menu_management_screen.dart - UPDATED WITH MENU TYPES
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import '../../models/menu_type.dart';
import '../../services/menu_operations_service.dart';

class MenuManagementScreen extends StatefulWidget {
  final MenuType? initialMenuType;
  
  const MenuManagementScreen({Key? key, this.initialMenuType}) : super(key: key);

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
  MenuType _selectedMenuType = MenuType.breakfast;
  
  // Tab state
  late TabController _tabController;
  
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
    _tabController = TabController(length: MenuType.values.length, vsync: this);
    
    // Set initial menu type if provided
    if (widget.initialMenuType != null) {
      _selectedMenuType = widget.initialMenuType!;
      _tabController.index = widget.initialMenuType!.index;
    }
    
    _setupAnimations();
    _initializeMenuOperations();
  }

  void _setupAnimations() {
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

  void _initializeMenuOperations() async {
    await MenuOperationsService.initializeMenuOperations();
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    _fadeController?.dispose();
    _slideController?.dispose();
    _tabController.dispose();
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

  // Upload image to Firebase Storage
  Future<String?> uploadImage(File imageFile) async {
    try {
      final String fileName = 'menu_items/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded_by': 'admin',
          'upload_time': DateTime.now().toIso8601String(),
        },
      );
      
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
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

  // Add new menu item with menu type
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
      
      if (_selectedImage != null) {
        final url = await uploadImage(_selectedImage!);
        if (url != null) {
          imageUrl = url;
        }
      }

      // Add to Firestore with menu type
      final docRef = await FirebaseFirestore.instance.collection('menuItems').add({
        'name': name,
        'price': price,
        'description': description,
        'imageUrl': imageUrl,
        'available': true,
        'isVeg': isVeg,
        'quantity': quantity,
        'hasUnlimitedStock': hasUnlimitedStock,
        'menuType': _selectedMenuType.value, // Add menu type
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Menu item added successfully with ID: ${docRef.id}');
      
      // Update menu item counts
      await MenuOperationsService.updateMenuItemCounts();
      
      resetForm();
      _showSnackBar('$name added to ${_selectedMenuType.displayName} menu!', Colors.green);
      
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

  // Edit menu item with menu type
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
        'menuType': _selectedMenuType.value, // Update menu type
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedImage != null) {
        final url = await uploadImage(_selectedImage!);
        if (url != null) {
          updateData['imageUrl'] = url;
        }
      }

      await FirebaseFirestore.instance
          .collection('menuItems')
          .doc(_editingItemId)
          .update(updateData);

      // Update menu item counts
      await MenuOperationsService.updateMenuItemCounts();

      resetForm();
      _showSnackBar('$name updated in ${_selectedMenuType.displayName} menu!', Colors.green);
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
      
      // Set menu type from existing data
      final menuTypeValue = data['menuType'] ?? 'breakfast';
      _selectedMenuType = MenuType.fromString(menuTypeValue);
      
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
      _selectedMenuType = MenuType.values[_tabController.index];
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
      
      // Update menu item counts
      await MenuOperationsService.updateMenuItemCounts();
      
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
          
      // Update menu item counts
      await MenuOperationsService.updateMenuItemCounts();
          
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
      
      // Update menu item counts
      await MenuOperationsService.updateMenuItemCounts();
    } catch (e) {
      _showSnackBar('Error updating stock: $e', Colors.red);
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
        actions: [
          if (!showAddForm && !showEditForm)
            IconButton(
              icon: Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(context, '/admin/menu-operations');
              },
              tooltip: 'Menu Operations',
            ),
        ],
        bottom: (!showAddForm && !showEditForm) 
          ? TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              onTap: (index) {
                setState(() {
                  _selectedMenuType = MenuType.values[index];
                });
              },
              tabs: MenuType.values.map((menuType) => Tab(
                icon: Icon(menuType.icon, size: 20),
                text: menuType.displayName,
              )).toList(),
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
                      _selectedMenuType = MenuType.values[_tabController.index];
                      showAddForm = true;
                    });
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFFB703),
                  icon: Icon(Icons.add),
                  label: Text(
                    "Add ${MenuType.values[_tabController.index].displayName} Item",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  elevation: 8,
                ),
              )
            : FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    _selectedMenuType = MenuType.values[_tabController.index];
                    showAddForm = true;
                  });
                },
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFFB703),
                icon: Icon(Icons.add),
                label: Text(
                  "Add ${MenuType.values[_tabController.index].displayName} Item",
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
                color: _selectedMenuType.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _selectedMenuType.icon,
                color: _selectedMenuType.color,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showEditForm ? "Edit ${_selectedMenuType.displayName} Item" : "Add ${_selectedMenuType.displayName} Item",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    showEditForm ? "Update menu item details" : "Create a new ${_selectedMenuType.displayName.toLowerCase()} item",
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
        
        // Menu Type Selection (only for add, not edit)
        if (!showEditForm) _buildMenuTypeSelector(),
        if (!showEditForm) const SizedBox(height: 24),
        
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

  Widget _buildMenuTypeSelector() {
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
              Icon(Icons.category, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Menu Category',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Menu type selection chips
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: MenuType.values.map((menuType) {
              final isSelected = _selectedMenuType == menuType;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMenuType = menuType;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? menuType.color.withOpacity(0.2)
                      : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                        ? menuType.color
                        : Colors.grey.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        menuType.icon,
                        color: isSelected ? menuType.color : Colors.grey[600],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        menuType.displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? menuType.color : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Continue with the rest of the widget methods (same as before)
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
              backgroundColor: _selectedMenuType.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 8,
              shadowColor: _selectedMenuType.color.withOpacity(0.4),
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
                      showEditForm ? "Update Item" : "Add to ${_selectedMenuType.displayName}",
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
              child: _buildTabContent(),
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
              child: _buildTabContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: MenuType.values.map((menuType) => _buildMenuTypeList(menuType)).toList(),
    );
  }

  Widget _buildMenuTypeList(MenuType menuType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header for each menu type
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: menuType.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  menuType.icon,
                  color: menuType.color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${menuType.displayName} Menu",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "Manage ${menuType.displayName.toLowerCase()} items",
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
        
        // Menu items list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: MenuOperationsService.getMenuItemsByType(menuType),
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
                        "Error loading ${menuType.displayName.toLowerCase()} items",
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
                      CircularProgressIndicator(
                        color: menuType.color,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Loading ${menuType.displayName.toLowerCase()} items...",
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
                          color: menuType.color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          menuType.icon,
                          size: 60,
                          color: menuType.color,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "No ${menuType.displayName.toLowerCase()} items yet",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Add your first ${menuType.displayName.toLowerCase()} item",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedMenuType = menuType;
                            showAddForm = true;
                          });
                        },
                        icon: Icon(Icons.add),
                        label: Text(
                          "Add ${menuType.displayName} Item",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: menuType.color,
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
                  
                  return _buildMenuItemCard(doc, data, menuType);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemCard(DocumentSnapshot doc, Map<String, dynamic> data, MenuType menuType) {
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
        border: Border.all(
          color: menuType.color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: menuType.color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  // Menu type badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: menuType.color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            menuType.icon,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            menuType.displayName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
                      _getStockStatusWidget(quantity, hasUnlimitedStock),
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
                            : menuType.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "₹${price.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock ? Colors.grey[500] : menuType.color,
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
  }

  Widget _getStockStatusWidget(int quantity, bool hasUnlimitedStock) {
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