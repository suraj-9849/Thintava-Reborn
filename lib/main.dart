import 'dart:async';
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

// Import your other screen files.
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/user/menu_screen.dart';
import 'screens/user/cart_screen.dart';
import 'screens/user/order_tracking_screen.dart';
import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/admin/menu_management_screen.dart';
import 'package:canteen_app/screens/kitchen/kitchen_dashboard.dart';
import 'package:canteen_app/screens/user/order_history_screen.dart';
import 'package:canteen_app/screens/admin/admin_order_history_screen.dart';
import 'package:canteen_app/screens/admin/admin_kitchen_view_screen.dart';
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// List of food quotes for inspiration
const List<String> foodQuotes = [
  "Good food is the foundation of genuine happiness.",
  "One cannot think well, love well, sleep well, if one has not dined well.",
  "People who love to eat are always the best people.",
  "Life is uncertain. Eat dessert first.",
  "Food brings people together on many different levels.",
  "Cooking is love made visible.",
  "Let food be thy medicine and medicine be thy food.",
  "There is no sincerer love than the love of food.",
  "Food is not just eating energy. It's an experience.",
  "Good food is good mood."
];

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Platform-specific Firebase initialization.
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCPsu2kuSKa9KezLhZNJWUF4B_n5kMqo4g",
        authDomain: "thintava-ee4f4.firebaseapp.com",
        projectId: "thintava-ee4f4",
        storageBucket: "thintava-ee4f4.firebasestorage.app",
        messagingSenderId: "626390741302",
        appId: "1:626390741302:ios:0579424d3bba31c12ec397",
        measurementId: "",
      ),
    );
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } else {
    await Firebase.initializeApp();
    await saveInitialFCMToken();
  }

  // 🔥 1. Initialize Firebase Messaging
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  
  // 🔥 2. Request permission
  await messaging.requestPermission();

  // 🔥 3. Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔥 4. Initialize local notifications (for showing popup inside app)
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();    

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

Future<void> saveInitialFCMToken() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': newToken,
      }, SetOptions(merge: true));
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thintava',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB703),
          primary: const Color(0xFFFFB703),
          secondary: const Color(0xFFFFB703), // Added the requested amber color
          tertiary: const Color(0xFF2196F3),
          background: const Color(0xFFF5F5F5),
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFFFFB703),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: const Color(0xFFFFB703).withOpacity(0.5),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFB703),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: const BorderSide(
              color: Color(0xFFFFB703),
              width: 1.5,
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 8,
          shadowColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFFFFB703),
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/auth': (_) => const AuthMenu(),
        '/menu': (_) => const MenuScreen(),
        '/cart': (context) {
          final cart = ModalRoute.of(context)!.settings.arguments as Map<String, int>;
          return CartScreen(cart: cart);
        },
        '/splash': (context) => const SplashScreen(),
        '/track': (_) => const OrderTrackingScreen(),
        '/kitchen': (_) => const KitchenDashboard(),
        '/kitchen-menu': (_) => const KitchenHome(),
        '/admin/menu': (_) => const MenuManagementScreen(),
        '/admin/home': (_) => const AdminHome(),
        '/history': (_) => const OrderHistoryScreen(),
        '/admin/admin-history': (_) => const AdminOrderHistoryScreen(),
        '/admin/admin-kitchen-view': (_) => const AdminKitchenViewScreen(),
        '/user/user-home': (_) => const UserHome(),
      },
    );
  }
}

/// SPLASH SCREEN WITH ROLE-BASED ROUTING
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  
  @override
  _SplashScreenState createState() => _SplashScreenState();
}
 
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupFirebaseMessaging();
    _startListeningToAuth();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'thintava_channel',
              'Thintava Notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  void _startListeningToAuth() {
    print("👂 Listening to authStateChanges...");
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;

      if (user == null) {
        print("🔴 No user. Navigating to /auth...");
        // Add a delay for splash screen effect
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      print("🟢 User signed in: ${user.uid}");

      // Important: START FCM Token Fetching
      await _fetchAndSaveFcmToken(user.uid);

      // Now fetch the user role
      final role = await _fetchUserRole(user.uid);

      if (!mounted) return;
      
      // Add a delay for splash screen effect
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin/home');
      } else if (role == 'kitchen') {
        Navigator.pushReplacementNamed(context, '/kitchen-menu');
      } else {
        Navigator.pushReplacementNamed(context, '/user/user-home');
      }
    });
  }

  Future<void> _fetchAndSaveFcmToken(String userId) async {
    try {
      print("🚀 Fetching FCM token...");
      String? token;
      int retries = 0;

      while (token == null && retries < 10) {
        token = await FirebaseMessaging.instance.getToken();
        if (token == null) {
          print("⏳ FCM token not ready, retrying... attempt $retries");
          await Future.delayed(const Duration(seconds: 1));
          retries++;
        }
      }

      if (token != null) {
        print("✅ Got FCM token: $token");
        await FirebaseFirestore.instance.collection('users').doc(userId).set(
          {'fcmToken': token},
          SetOptions(merge: true),
        );

        // Also listen for future token refreshes
        _tokenRefreshSubscription?.cancel();
        _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          print("🔄 FCM token refreshed: $newToken");
          await FirebaseFirestore.instance.collection('users').doc(userId).set(
            {'fcmToken': newToken},
            SetOptions(merge: true),
          );
        });
      } else {
        print("❗ Error fetching FCM token after retries.");
      }
    } catch (e) {
      print("❗ Error fetching FCM token: $e");
    }
  }

  Future<String> _fetchUserRole(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['role'] ?? 'user';
      } else {
        return 'user';
      }
    } catch (e) {
      print("❗ Error fetching role: $e");
      return 'user';
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _tokenRefreshSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB703), Color(0xFFFFB703)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container with shadow effect
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    size: 60,
                    color: Color(0xFFFFB703),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Thintava',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                // Random food quote from our list
                Text(
                  foodQuotes[DateTime.now().second % foodQuotes.length],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  "Preparing your experience...",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// AUTH MENU (Login/Register Options)
class AuthMenu extends StatelessWidget {
  const AuthMenu({super.key});
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Get a random food quote
    final randomQuote = foodQuotes[DateTime.now().second % foodQuotes.length];
  
    return Scaffold(
      body: Stack(
        children: [
          // Curved header background with gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.5,
            child: ClipPath(
              clipper: CurvedClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFB703), // Green
                      Color(0xFFFFB703), // Amber/Gold (New Requested Color)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // App content with animations
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  FadeInWidget(
                    delay: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              )
                            ],
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 36,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Thintava',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Animated text for tagline
                  FadeInWidget(
                    delay: 300,
                    child: AnimatedTextKit(
                      animatedTexts: [
                        TypewriterAnimatedText(
                          'Delicious food at your fingertips',
                          textStyle: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                          speed: const Duration(milliseconds: 100),
                        ),
                      ],
                      totalRepeatCount: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Food Quote
                  FadeInWidget(
                    delay: 400,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '"$randomQuote"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Animated card with login/register options
                  FadeInWidget(
                    delay: 600,
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                        child: Column(
                          children: [
                            Text(
                              'Welcome Back',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const LoginScreen(),
                                      transitionDuration: const Duration(milliseconds: 300),
                                      transitionsBuilder: (_, animation, __, child) {
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(1, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: Text(
                                  "Login",
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const RegisterScreen(),
                                      transitionDuration: const Duration(milliseconds: 300),
                                      transitionsBuilder: (_, animation, __, child) {
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(1, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: Text(
                                  "Register",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  FadeInWidget(
                    delay: 800,
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// MENU SCREEN (Home for logged-in users)
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  final cart = <String, int>{};
  final searchController = TextEditingController();
  String filterOption = "All"; // Options: "All", "Veg", "Non Veg"
  late TabController _tabController;
  final List<String> categories = ["All", "Breakfast", "Lunch", "Dinner", "Snacks", "Beverages"];
  String selectedCategory = "All";
  bool isGridView = true; // Toggle between grid and list view

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          selectedCategory = categories[_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void increaseQuantity(String itemId) {
    setState(() {
      cart[itemId] = (cart[itemId] ?? 0) + 1;
    });
  }

  void decreaseQuantity(String itemId) {
    setState(() {
      if (cart[itemId] != null && cart[itemId]! > 0) {
        cart[itemId] = cart[itemId]! - 1;
      }
    });
  }

  Future<bool> _onWillPop() async {
    // Show confirmation dialog on back press.
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        )) ??
        false;
  }

  // Get today's featured quote
  String get featuredQuote {
    final dayOfYear = DateTime.now().dayOfYear;
    return foodQuotes[dayOfYear % foodQuotes.length];
  }

  @override
  Widget build(BuildContext context) {
    final menuStream =
        FirebaseFirestore.instance.collection('menuItems').snapshots();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: "Back",
            onPressed: () async {
              if (await _onWillPop()) {
                // Exit logic
              }
            },
          ),
          title: Text(
            "Menu",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: "Order History",
              onPressed: () {
                Navigator.pushNamed(context, '/history');
              },
            ),
            IconButton(
              icon: const Icon(Icons.track_changes),
              tooltip: "Track Order",
              onPressed: () {
                Navigator.pushNamed(context, '/track');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Logout",
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/auth');
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: categories.map((cat) => Tab(text: cat)).toList(),
            indicatorColor: const Color(0xFFFFB703),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: Column(
          children: [
            // Quote of the day banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB703), Color(0xFFFFC233)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      featuredQuote,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Search bar and filter row.
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search food items",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<String>(
                      value: filterOption,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.filter_list),
                      onChanged: (newValue) {
                        setState(() {
                          filterOption = newValue!;
                        });
                      },
                      items: <String>["All", "Veg", "Non Veg"]
                          .map((String value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // View toggle button
                  IconButton(
                    icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
                    onPressed: () {
                      setState(() {
                        isGridView = !isGridView;
                      });
                    },
                    tooltip: isGridView ? "List View" : "Grid View",
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Menu items list with animations
            Expanded(
              child: StreamBuilder(
                stream: menuStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                      ),
                    );
                  }

                  final items = snapshot.data!.docs;
                  // Filter items based on search text, category and veg/non-veg filter
                  final filteredItems = items.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? "").toString().toLowerCase();
                    final category = (data['category'] ?? "All").toString();
                    final searchText = searchController.text.toLowerCase();
                    
                    bool matchesSearch = name.contains(searchText);
                    
                    // Check category filter
                    bool matchesCategory = selectedCategory == "All" || 
                                           category == selectedCategory;

                    // Check the veg filter
                    bool matchesFilter = true;
                    if (filterOption == "Veg") {
                      matchesFilter = data['isVeg'] == true;
                    } else if (filterOption == "Non Veg") {
                      matchesFilter = data['isVeg'] == false;
                    }
                    
                    return matchesSearch && matchesFilter && matchesCategory;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No items found",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Try changing your search or filters",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Switch between grid and list view
                  return isGridView 
                      ? _buildGridView(filteredItems)
                      : _buildListView(filteredItems);
                },
              ),
            )
          ],
        ),
        floatingActionButton: Stack(
          alignment: Alignment.topRight,
          children: [
            FloatingActionButton(
              heroTag: "cart_button",
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.white,
              tooltip: "Go to Cart",
              onPressed: () {
                Navigator.pushNamed(context, '/cart', arguments: cart);
              },
              child: const Icon(Icons.shopping_cart),
            ),
            // Cart item count badge
            if (cart.isNotEmpty)
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB703),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      cart.values.fold(0, (sum, qty) => sum + qty).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Grid view for menu items
  Widget _buildGridView(List<QueryDocumentSnapshot> items) {
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildGridItem(items[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  // Individual grid item
  Widget _buildGridItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;
    int quantity = cart[id] ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image with veg/non-veg indicator
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: data['imageUrl'] != null
                    ? Image.network(
                        data['imageUrl'],
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: double.infinity,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.fastfood, size: 50),
                      ),
              ),
              // Veg/Non-veg indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    data['isVeg'] == true ? Icons.circle : Icons.square,
                    color: data['isVeg'] == true ? Colors.green : Colors.red,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Item',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "₹${data['price']}",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFFFFB703),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Quantity controller
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: quantity > 0 ? Colors.red : Colors.grey,
                      onPressed: () => decreaseQuantity(id),
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: quantity > 0 ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        quantity.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: quantity > 0 ? const Color(0xFF4CAF50) : Colors.grey,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: const Color(0xFF4CAF50),
                      onPressed: () => increaseQuantity(id),
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // List view for menu items
  Widget _buildListView(List<QueryDocumentSnapshot> items) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildListItem(items[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  // Individual list item
  Widget _buildListItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;
    int quantity = cart[id] ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Food Image with veg/non-veg indicator
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: data['imageUrl'] != null
                    ? Image.network(
                        data['imageUrl'],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(Icons.fastfood, size: 50),
                      ),
                ),
                // Veg/Non-veg indicator
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      data['isVeg'] == true ? Icons.circle : Icons.square,
                      color: data['isVeg'] == true ? Colors.green : Colors.red,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            
            // Dish Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['name'] ?? 'Item',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB703).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "₹${data['price']}",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFB703),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Description if available
                  if (data['description'] != null)
                    Text(
                      data['description'],
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  // Category and estimated time
                  Row(
                    children: [
                      if (data['category'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            data['category'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (data['estimatedTime'] != null)
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              "${data['estimatedTime']} min",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Quantity controller - vertical layout
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: const Color(0xFF4CAF50),
                  onPressed: () => increaseQuantity(id),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: quantity > 0 ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quantity.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: quantity > 0 ? const Color(0xFF4CAF50) : Colors.grey,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle),
                  color: quantity > 0 ? Colors.red : Colors.grey,
                  onPressed: () => decreaseQuantity(id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// CUSTOM CLIPPER FOR CURVED HEADER DESIGN
class CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    // Start from top left.
    path.lineTo(0, size.height - 60);
    // Create a more dramatic wave effect
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);
        
    var secondControlPoint = Offset(size.width * 3 / 4, size.height - 60);
    var secondEndPoint = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);
        
    path.lineTo(size.width, 0);
    // Close the path.
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// FADE IN WIDGET FOR ANIMATIONS
class FadeInWidget extends StatelessWidget {
  final Widget child;
  final int delay;
  const FadeInWidget({Key? key, required this.child, this.delay = 0})
      : super(key: key);
      
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      // Added delay functionality
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// Extension to get day of year for date
extension DateTimeExtensions on DateTime {
  int get dayOfYear {
    return difference(DateTime(year, 1, 1)).inDays;
  }
}