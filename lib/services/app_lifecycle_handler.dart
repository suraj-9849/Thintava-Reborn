// lib/services/enhanced_app_lifecycle_handler.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:canteen_app/models/reservation_model.dart';
import 'package:canteen_app/services/reservation_service.dart';
import 'dart:async';

class EnhancedAppLifecycleHandler extends WidgetsBindingObserver {
  static EnhancedAppLifecycleHandler? _instance;
  BuildContext? _context;
  bool _isInPaymentProcess = false;
  DateTime? _paymentStartTime;
  Timer? _cleanupTimer;
  
  EnhancedAppLifecycleHandler._();
  
  static EnhancedAppLifecycleHandler get instance {
    _instance ??= EnhancedAppLifecycleHandler._();
    return _instance!;
  }
  
  void initialize(BuildContext context) {
    _context = context;
    WidgetsBinding.instance.addObserver(this);
    print('🔄 Enhanced app lifecycle handler initialized');
    
    // Test the handler immediately to ensure it's working
    _testHandler();
  }
  
  void _testHandler() {
    print('🧪 Testing lifecycle handler integration...');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('✅ User authenticated: ${user.uid}');
    } else {
      print('⚠️ No user authenticated');
    }
    
    if (_context != null) {
      print('✅ Context available');
      try {
        final cartProvider = Provider.of<CartProvider>(_context!, listen: false);
        print('✅ Cart provider accessible');
        print('📊 Current cart items: ${cartProvider.itemCount}');
        print('📊 Active reservations: ${cartProvider.hasActiveReservations}');
      } catch (e) {
        print('❌ Error accessing cart provider: $e');
      }
    } else {
      print('❌ No context available');
    }
  }
  
  void dispose() {
    _cleanupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _context = null;
    print('🛑 Enhanced app lifecycle handler disposed');
  }
  
  // Mark that payment process has started
  void markPaymentProcessStarted() {
    _isInPaymentProcess = true;
    _paymentStartTime = DateTime.now();
    print('💳 Payment process started - enhanced monitoring enabled');
    print('📱 Current app state: ${WidgetsBinding.instance.lifecycleState}');
    
    // Start a safety timer that releases reservations after 15 minutes regardless
    _startSafetyTimer();
  }
  
  // Mark that payment process has completed (success or failure)
  void markPaymentProcessCompleted() {
    _isInPaymentProcess = false;
    _paymentStartTime = null;
    _cleanupTimer?.cancel();
    print('✅ Payment process completed - enhanced monitoring disabled');
  }
  
  void _startSafetyTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(const Duration(minutes: 15), () {
      if (_isInPaymentProcess) {
        print('⏰ Safety timer triggered - releasing reservations after 15 minutes');
        _releaseReservationsOnAppClose();
      }
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('📱 App lifecycle state changed: $state (Payment in progress: $_isInPaymentProcess)');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }
  
  void _handleAppResumed() {
    print('▶️ App resumed');
    if (_isInPaymentProcess && _paymentStartTime != null) {
      final timeSincePaymentStart = DateTime.now().difference(_paymentStartTime!);
      print('⏱️ Time since payment started: ${timeSincePaymentStart.inSeconds} seconds');
    }
  }
  
  void _handleAppInactive() {
    print('⏸️ App inactive (temporary - like notification or call)');
    // Don't release reservations for inactive state as it's usually temporary
  }
  
  void _handleAppPaused() {
    print('⏸️ App paused (backgrounded)');
    
    if (_isInPaymentProcess) {
      print('💳 App paused during payment - starting countdown for reservation release');
      
      // Start a 5-second countdown before releasing reservations
      // This gives users time if they're just switching apps briefly
      Timer(const Duration(seconds: 5), () {
        final currentState = WidgetsBinding.instance.lifecycleState;
        print('🔍 Checking state after 5 seconds: $currentState');
        
        if ((currentState == AppLifecycleState.paused || 
             currentState == AppLifecycleState.detached ||
             currentState == AppLifecycleState.hidden) && 
            _isInPaymentProcess) {
          print('💳 App still backgrounded after 5 seconds - releasing reservations');
          _releaseReservationsOnAppClose();
        } else {
          print('✅ App returned to foreground - keeping reservations');
        }
      });
    }
  }
  
  void _handleAppHidden() {
    print('🫥 App hidden');
    
    if (_isInPaymentProcess) {
      print('💳 App hidden during payment - releasing reservations immediately');
      _releaseReservationsOnAppClose();
    }
  }
  
  void _handleAppDetached() {
    print('🔌 App detached (being terminated)');
    
    if (_isInPaymentProcess) {
      print('💳 App terminated during payment - releasing reservations immediately');
      _releaseReservationsOnAppClose();
    }
  }
  
  void _releaseReservationsOnAppClose() async {
    try {
      print('🔄 Starting enhanced reservation release process...');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user authenticated for releasing reservations');
        return;
      }
      
      print('👤 Releasing reservations for user: ${user.uid}');
      
      // Method 1: Try to use cart provider if context is available
      bool releasedViaCartProvider = false;
      
      try {
        if (_context != null && _context!.mounted) {
          final cartProvider = Provider.of<CartProvider>(_context!, listen: false);
          
          if (cartProvider.hasActiveReservations) {
            print('🔄 Method 1: Releasing via cart provider...');
            print('📊 Active reservations count: ${cartProvider.activeReservations.length}');
            
            final success = await cartProvider.releaseReservations(
              status: ReservationStatus.cancelled,
            );
            
            if (success) {
              print('✅ Method 1 successful: Reservations released via cart provider');
              releasedViaCartProvider = true;
            } else {
              print('❌ Method 1 failed: Cart provider release failed');
            }
          } else {
            print('ℹ️ Method 1: No active reservations in cart provider');
          }
        } else {
          print('⚠️ Method 1 skipped: Context not available or not mounted');
        }
      } catch (e) {
        print('❌ Method 1 error: $e');
      }
      
      // Method 2: Direct service call if cart provider method failed
      if (!releasedViaCartProvider) {
        print('🔄 Method 2: Using direct reservation service...');
        
        try {
          final success = await ReservationService.releaseAllUserReservations(user.uid);
          
          if (success) {
            print('✅ Method 2 successful: Direct reservation release completed');
          } else {
            print('❌ Method 2 failed: Direct reservation release failed');
          }
        } catch (e) {
          print('❌ Method 2 error: $e');
        }
      }
      
      // Reset payment process flag
      _isInPaymentProcess = false;
      _paymentStartTime = null;
      _cleanupTimer?.cancel();
      
      print('🏁 Reservation release process completed');
      
    } catch (e) {
      print('❌ Critical error in reservation release: $e');
      
      // Final attempt: Try one more time with just the user ID
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          print('🔄 Final attempt: Emergency reservation release...');
          await ReservationService.releaseAllUserReservations(user.uid);
          print('✅ Emergency release completed');
        }
      } catch (emergencyError) {
        print('❌ Emergency release failed: $emergencyError');
      }
      
      // Always reset the flags even if release failed
      _isInPaymentProcess = false;
      _paymentStartTime = null;
      _cleanupTimer?.cancel();
    }
  }
  
  // Debug method to check current state
  void debugCurrentState() {
    print('🐛 DEBUG: Current lifecycle state');
    print('  - App state: ${WidgetsBinding.instance.lifecycleState}');
    print('  - In payment: $_isInPaymentProcess');
    print('  - Payment start: $_paymentStartTime');
    print('  - Context available: ${_context != null}');
    
    if (_context != null) {
      try {
        final cartProvider = Provider.of<CartProvider>(_context!, listen: false);
        print('  - Cart items: ${cartProvider.itemCount}');
        print('  - Active reservations: ${cartProvider.hasActiveReservations}');
        print('  - Reservation count: ${cartProvider.activeReservations.length}');
      } catch (e) {
        print('  - Cart provider error: $e');
      }
    }
    
    final user = FirebaseAuth.instance.currentUser;
    print('  - User: ${user?.uid ?? 'Not authenticated'}');
  }
  
  // Manual trigger for testing
  void manuallyTriggerReservationRelease() {
    print('🧪 MANUAL TRIGGER: Releasing reservations for testing');
    _releaseReservationsOnAppClose();
  }
}