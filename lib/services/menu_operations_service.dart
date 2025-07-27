// lib/services/menu_operations_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
            isCurrentlyActive: false,
            schedule: MenuSchedule.defaultSchedule(menuType),
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

  /// Update menu schedule
  static Future<bool> updateMenuSchedule(MenuType menuType, MenuSchedule schedule) async {
    try {
      await _firestore.collection('menuOperations').doc(menuType.value).update({
        'schedule': schedule.toMap(),
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      
      print('✅ Menu ${menuType.displayName} schedule updated');
      return true;
    } catch (e) {
      print('❌ Error updating menu schedule: $e');
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
          final isCurrentlyActive = status.schedule.isCurrentlyActive();
          
          statuses.add(status.copyWith(isCurrentlyActive: isCurrentlyActive));
        }
      }
      
      // Ensure all menu types are present
      for (MenuType menuType in MenuType.values) {
        if (!statuses.any((status) => status.menuType == menuType)) {
          statuses.add(OperationalStatus(
            menuType: menuType,
            isEnabled: false,
            isCurrentlyActive: false,
            schedule: MenuSchedule.defaultSchedule(menuType),
            lastUpdated: DateTime.now(),
          ));
        }
      }
      
      // Sort by menu type order
      statuses.sort((a, b) => a.menuType.index.compareTo(b.menuType.index));
      
      return statuses;
    });
  }

  /// Get currently active menu types (enabled and in operating hours)
  static Future<List<MenuType>> getActiveMenuTypes() async {
    try {
      final snapshot = await _firestore.collection('menuOperations').get();
      List<MenuType> activeMenus = [];
      
      for (var doc in snapshot.docs) {
        if (doc.exists) {
          final status = OperationalStatus.fromMap(doc.data());
          final isCurrentlyActive = status.schedule.isCurrentlyActive();
          
          if (status.isEnabled && isCurrentlyActive) {
            activeMenus.add(status.menuType);
          }
        }
      }
      
      return activeMenus;
    } catch (e) {
      print('❌ Error getting active menu types: $e');
      return [];
    }
  }

  /// Check if canteen is operational (any menu is active)
  static Future<bool> isCanteenOperational() async {
    final activeMenus = await getActiveMenuTypes();
    return activeMenus.isNotEmpty;
  }

  /// Get next operational time
  static Future<MenuSchedule?> getNextOperationalTime() async {
    try {
      final snapshot = await _firestore.collection('menuOperations').get();
      MenuSchedule? nextSchedule;
      TimeOfDay? earliestTime;
      
      final now = TimeOfDay.now();
      final currentMinutes = now.hour * 60 + now.minute;
      
      for (var doc in snapshot.docs) {
        if (doc.exists) {
          final status = OperationalStatus.fromMap(doc.data());
          if (status.isEnabled) {
            final schedule = status.schedule;
            final startMinutes = schedule.startTime.hour * 60 + schedule.startTime.minute;
            
            // If this menu starts later today
            if (startMinutes > currentMinutes) {
              if (earliestTime == null || startMinutes < (earliestTime.hour * 60 + earliestTime.minute)) {
                earliestTime = schedule.startTime;
                nextSchedule = schedule;
              }
            }
          }
        }
      }
      
      // If no menu today, check tomorrow's earliest menu
      if (nextSchedule == null) {
        for (var doc in snapshot.docs) {
          if (doc.exists) {
            final status = OperationalStatus.fromMap(doc.data());
            if (status.isEnabled) {
              final schedule = status.schedule;
              final startMinutes = schedule.startTime.hour * 60 + schedule.startTime.minute;
              
              if (earliestTime == null || startMinutes < (earliestTime.hour * 60 + earliestTime.minute)) {
                earliestTime = schedule.startTime;
                nextSchedule = schedule;
              }
            }
          }
        }
      }
      
      return nextSchedule;
    } catch (e) {
      print('❌ Error getting next operational time: $e');
      return null;
    }
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

  /// Get all menu items filtered by active menu types
  static Stream<QuerySnapshot> getActiveMenuItems() async* {
    final activeMenuTypes = await getActiveMenuTypes();
    
    if (activeMenuTypes.isEmpty) {
      // Yield empty snapshot if no menus are active
      yield* Stream.empty();
      return;
    }

    final activeMenuValues = activeMenuTypes.map((type) => type.value).toList();
    
    yield* _firestore
        .collection('menuItems')
        .where('menuType', whereIn: activeMenuValues)
        .snapshots();
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
        final isCurrentlyActive = status.schedule.isCurrentlyActive();
        return status.copyWith(isCurrentlyActive: isCurrentlyActive);
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
      final activeMenus = statuses.where((s) => s.canShowToUsers).toList();
      final nextOperational = await getNextOperationalTime();
      
      return {
        'isOperational': activeMenus.isNotEmpty,
        'activeMenuCount': activeMenus.length,
        'totalMenus': statuses.length,
        'activeMenus': activeMenus.map((s) => s.menuType.displayName).toList(),
        'nextOperationalTime': nextOperational?.getFormattedTimeRange(),
        'nextOperationalMenu': nextOperational?.menuType.displayName,
      };
    } catch (e) {
      print('❌ Error getting canteen status summary: $e');
      return {
        'isOperational': false,
        'activeMenuCount': 0,
        'totalMenus': 3,
        'activeMenus': [],
        'nextOperationalTime': null,
        'nextOperationalMenu': null,
      };
    }
  }
}

// Wrapper class to simulate QuerySnapshot for filtered results
class QuerySnapshotWrapper {
  final List<DocumentSnapshot> docs;
  
  QuerySnapshotWrapper(this.docs);
  
  bool get hasData => true;
  dynamic get data => null;
  dynamic get error => null;
  ConnectionState get connectionState => ConnectionState.active;
}