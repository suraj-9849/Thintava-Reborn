// lib/services/menu_operations_service.dart - CLEAN VERSION WITHOUT DUPLICATES
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_type.dart';

class MenuOperationsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize default menu operations if they don't exist
  static Future<void> initializeMenuOperations() async {
    try {
      final batch = _firestore.batch();
      
      for (MenuType menuType in MenuType.values) {
        final docRef = _firestore.collection('menuOperations').doc(menuType.value);
        final doc = await docRef.get();
        
        if (!doc.exists) {
          final defaultStatus = OperationalStatus(
            menuType: menuType,
            isEnabled: false,
            lastUpdated: DateTime.now(),
          );
          
          batch.set(docRef, defaultStatus.toMap());
        }
      }
      
      await batch.commit();
      print('✅ Menu operations initialized');
    } catch (e) {
      print('❌ Error initializing menu operations: $e');
    }
  }

  /// Toggle menu enabled status
  static Future<bool> toggleMenuEnabled(MenuType menuType, bool enabled) async {
    try {
      await _firestore.collection('menuOperations').doc(menuType.value).update({
        'isEnabled': enabled,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      
      print('✅ Menu ${menuType.displayName} ${enabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      print('❌ Error toggling menu: $e');
      return false;
    }
  }

  /// Get all menu operational statuses
  static Stream<List<OperationalStatus>> getMenuOperationalStatuses() {
    return _firestore.collection('menuOperations').snapshots().map((snapshot) {
      List<OperationalStatus> statuses = [];
      
      for (var doc in snapshot.docs) {
        if (doc.exists) {
          final status = OperationalStatus.fromMap(doc.data());
          statuses.add(status);
        }
      }
      
      // Ensure all menu types are present
      for (MenuType menuType in MenuType.values) {
        if (!statuses.any((status) => status.menuType == menuType)) {
          statuses.add(OperationalStatus(
            menuType: menuType,
            isEnabled: false,
            lastUpdated: DateTime.now(),
          ));
        }
      }
      
      // Sort by menu type order
      statuses.sort((a, b) => a.menuType.index.compareTo(b.menuType.index));
      
      return statuses;
    });
  }

  /// Get currently enabled menu types
  static Future<List<MenuType>> getEnabledMenuTypes() async {
    try {
      final snapshot = await _firestore.collection('menuOperations').get();
      List<MenuType> enabledMenus = [];
      
      for (var doc in snapshot.docs) {
        if (doc.exists) {
          final status = OperationalStatus.fromMap(doc.data());
          
          if (status.isEnabled) {
            enabledMenus.add(status.menuType);
          }
        }
      }
      
      return enabledMenus;
    } catch (e) {
      print('❌ Error getting enabled menu types: $e');
      return [];
    }
  }

  /// Check if canteen is operational (any menu is enabled)
  static Future<bool> isCanteenOperational() async {
    final enabledMenus = await getEnabledMenuTypes();
    return enabledMenus.isNotEmpty;
  }

  /// Update menu item counts for operational status
  static Future<void> updateMenuItemCounts() async {
    try {
      final batch = _firestore.batch();
      
      for (MenuType menuType in MenuType.values) {
        final itemsSnapshot = await _firestore
            .collection('menuItems')
            .where('menuType', isEqualTo: menuType.value)
            .get();
        
        int totalItems = itemsSnapshot.docs.length;
        int availableItems = itemsSnapshot.docs.where((doc) {
          final data = doc.data();
          final available = data['available'] ?? false;
          final hasUnlimitedStock = data['hasUnlimitedStock'] ?? false;
          final quantity = data['quantity'] ?? 0;
          
          return available && (hasUnlimitedStock || quantity > 0);
        }).length;
        
        final docRef = _firestore.collection('menuOperations').doc(menuType.value);
        batch.update(docRef, {
          'itemCount': totalItems,
          'availableItemCount': availableItems,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }
      
      await batch.commit();
      print('✅ Menu item counts updated');
    } catch (e) {
      print('❌ Error updating menu item counts: $e');
    }
  }

  /// Get menu items for specific menu type
  static Stream<QuerySnapshot> getMenuItemsByType(MenuType menuType) {
    return _firestore
        .collection('menuItems')
        .where('menuType', isEqualTo: menuType.value)
        .orderBy('name')
        .snapshots();
  }

  /// Get enabled menu items filtered by enabled menu types
  static Stream<QuerySnapshot> getEnabledMenuItems() async* {
    final enabledMenuTypes = await getEnabledMenuTypes();
    
    if (enabledMenuTypes.isEmpty) {
      yield* Stream.empty();
      return;
    }

    try {
      final enabledMenuValues = enabledMenuTypes.map((type) => type.value).toList();
      
      // Use client-side filtering to avoid compound query issues
      yield* _firestore
          .collection('menuItems')
          .orderBy('name')
          .snapshots()
          .map((snapshot) {
            final filteredDocs = snapshot.docs.where((doc) {
              final data = doc.data();
              final menuType = data['menuType'] ?? 'breakfast';
              return enabledMenuValues.contains(menuType);
            }).toList();
            
            return _FilteredQuerySnapshot(filteredDocs);
          });
    } catch (e) {
      print('❌ Error getting enabled menu items: $e');
      yield* Stream.empty();
    }
  }

  /// Force enable menu (admin override)
  static Future<bool> forceEnableMenu(MenuType menuType) async {
    try {
      await _firestore.collection('menuOperations').doc(menuType.value).update({
        'isEnabled': true,
        'lastUpdated': DateTime.now().toIso8601String(),
        'forceEnabled': true,
        'forceEnabledAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ Menu ${menuType.displayName} force enabled');
      return true;
    } catch (e) {
      print('❌ Error force enabling menu: $e');
      return false;
    }
  }

  /// Disable all menus (emergency shutdown)
  static Future<bool> disableAllMenus() async {
    try {
      final batch = _firestore.batch();
      
      for (MenuType menuType in MenuType.values) {
        final docRef = _firestore.collection('menuOperations').doc(menuType.value);
        batch.update(docRef, {
          'isEnabled': false,
          'lastUpdated': DateTime.now().toIso8601String(),
          'emergencyDisabled': true,
          'emergencyDisabledAt': DateTime.now().toIso8601String(),
        });
      }
      
      await batch.commit();
      print('✅ All menus disabled');
      return true;
    } catch (e) {
      print('❌ Error disabling all menus: $e');
      return false;
    }
  }

  /// Get operational status for specific menu type
  static Future<OperationalStatus?> getMenuOperationalStatus(MenuType menuType) async {
    try {
      final doc = await _firestore.collection('menuOperations').doc(menuType.value).get();
      
      if (doc.exists) {
        final status = OperationalStatus.fromMap(doc.data()!);
        return status;
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting menu operational status: $e');
      return null;
    }
  }

  /// Check if specific menu type is currently available to users
  static Future<bool> isMenuTypeAvailable(MenuType menuType) async {
    final status = await getMenuOperationalStatus(menuType);
    return status?.canShowToUsers ?? false;
  }

  /// Get canteen status summary
  static Future<Map<String, dynamic>> getCanteenStatusSummary() async {
    try {
      final statuses = await getMenuOperationalStatuses().first;
      final enabledMenus = statuses.where((s) => s.canShowToUsers).toList();
      
      return {
        'isOperational': enabledMenus.isNotEmpty,
        'enabledMenuCount': enabledMenus.length,
        'totalMenus': statuses.length,
        'enabledMenus': enabledMenus.map((s) => s.menuType.displayName).toList(),
      };
    } catch (e) {
      print('❌ Error getting canteen status summary: $e');
      return {
        'isOperational': false,
        'enabledMenuCount': 0,
        'totalMenus': 3,
        'enabledMenus': [],
      };
    }
  }
}

// Helper class for filtered query snapshots
class _FilteredQuerySnapshot implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;

  _FilteredQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot> get docs => _docs;
  
  @override
  List<DocumentChange> get docChanges => [];
  
  @override
  SnapshotMetadata get metadata => _FilteredSnapshotMetadata();
  
  @override
  int get size => _docs.length;
  
  @override
  bool get isEmpty => _docs.isEmpty;
}

class _FilteredSnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
  
  @override
  bool get isFromCache => false;
}