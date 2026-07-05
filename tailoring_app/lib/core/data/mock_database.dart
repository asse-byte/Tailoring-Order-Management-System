import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/customers/domain/entities/measurements.dart';
import '../../features/orders/domain/entities/order.dart';
import '../../features/notifications/domain/entities/app_notification.dart';
import '../../firebase_options.dart';

/// A mock implementation of Firebase User that only implements the required fields
/// for the app to function when Firebase is not initialized.
class MockUser implements User {
  @override
  final String uid;
  
  @override
  final String? email;

  MockUser(this.uid, [this.email]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDatabase {
  MockDatabase._();
  static final MockDatabase instance = MockDatabase._();

  static bool get useMock {
    try {
      final String apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      return apiKey.startsWith('REPLACE_WITH_');
    } catch (_) {
      return true;
    }
  }

  bool _initialized = false;
  late SharedPreferences _prefs;

  final List<AppUser> _users = [];
  final Map<String, String> _userPasswords = {}; // email -> password
  final List<Measurements> _measurements = [];
  final List<TailoringOrder> _orders = [];
  final List<AppNotification> _notifications = [];
  final List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _staff = [];
  final List<Map<String, dynamic>> _readyToWear = [];
  final List<Map<String, dynamic>> _appointments = [];

  final StreamController<User?> _authController = StreamController<User?>.broadcast();
  
  Stream<User?> get authStateChangesStream {
    final controller = StreamController<User?>();
    // Emit current state immediately to the subscriber
    controller.add(_currentUser == null ? null : MockUser(_currentUser!.id, _currentUser!.email));
    
    final subscription = _authController.stream.listen((user) {
      controller.add(user);
    });
    
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };
    
    return controller.stream;
  }

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  set currentUser(AppUser? user) {
    _currentUser = user;
    if (user == null) {
      _authController.add(null);
      if (_initialized) {
        _prefs.remove('mock_current_user_id');
      }
    } else {
      _authController.add(MockUser(user.id, user.email));
      if (_initialized) {
        _prefs.setString('mock_current_user_id', user.id);
      }
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    
    // Load users
    final String? usersJson = _prefs.getString('mock_users');
    if (usersJson != null) {
      try {
        final List<dynamic> list = jsonDecode(usersJson);
        for (final item in list) {
          _users.add(AppUser.fromMap(item['userId'], item));
        }
      } catch (_) {}
    }

    // Ensure we always have the default Admin, Demo Customer, and Demo Secretary if they don't exist
    bool hasAdmin = false;
    bool hasCustomer = false;
    bool hasSecretary = false;
    for (final u in _users) {
      if (u.role == 'admin') hasAdmin = true;
      if (u.role == 'customer') hasCustomer = true;
      if (u.role == 'secretary') hasSecretary = true;
    }

    if (!hasAdmin) {
      _users.add(const AppUser(
        id: 'admin_uid',
        name: 'Shop Admin',
        email: 'admin@tailor.app',
        phone: '123456789',
        role: 'admin',
      ));
      _userPasswords['admin@tailor.app'] = 'Admin@1234';
      await _saveUsers();
    }

    if (!hasCustomer) {
      _users.add(const AppUser(
        id: 'customer_uid',
        name: 'Jane Doe',
        email: 'customer@tailor.app',
        phone: '987654321',
        role: 'customer',
      ));
      _userPasswords['customer@tailor.app'] = '123456';
      await _saveUsers();
    }

    if (!hasSecretary) {
      _users.add(const AppUser(
        id: 'secretary_uid',
        name: 'Shop Secretary',
        email: 'secretary@tailor.app',
        phone: '555444333',
        role: 'secretary',
      ));
      _userPasswords['secretary@tailor.app'] = 'Secretary@1234';
      await _saveUsers();
    }

    // Load passwords
    final String? passwordsJson = _prefs.getString('mock_passwords');
    if (passwordsJson != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(passwordsJson);
        map.forEach((k, v) => _userPasswords[k] = v.toString());
      } catch (_) {}
    } else {
      _userPasswords['admin@tailor.app'] = 'Admin@1234';
      _userPasswords['customer@tailor.app'] = '123456';
      _userPasswords['secretary@tailor.app'] = 'Secretary@1234';
      await _savePasswords();
    }

    // Load measurements
    final String? measurementsJson = _prefs.getString('mock_measurements');
    if (measurementsJson != null) {
      try {
        final List<dynamic> list = jsonDecode(measurementsJson);
        for (final item in list) {
          _measurements.add(Measurements.fromMap(item['userId'], item));
        }
      } catch (_) {}
    }

    // Load orders
    final String? ordersJson = _prefs.getString('mock_orders');
    if (ordersJson != null) {
      try {
        final List<dynamic> list = jsonDecode(ordersJson);
        for (final item in list) {
          _orders.add(TailoringOrder.fromMap(item['orderId'], item));
        }
      } catch (_) {}
    }

    // Load notifications
    final String? notificationsJson = _prefs.getString('mock_notifications');
    if (notificationsJson != null) {
      try {
        final List<dynamic> list = jsonDecode(notificationsJson);
        for (final item in list) {
          _notifications.add(AppNotification.fromMap(item['notificationId'], item));
        }
      } catch (_) {}
    }

    // Load products
    final String? productsJson = _prefs.getString('mock_products');
    if (productsJson != null) {
      try {
        final List<dynamic> list = jsonDecode(productsJson);
        _products.addAll(list.cast<Map<String, dynamic>>());
      } catch (_) {}
    } else {
      _products.addAll([
        {
          'id': 'p1',
          'name': 'Oud Intense',
          'category': 'perfume',
          'price': 15000.0,
          'quantity': 12,
          'description': 'Premium Malian oud perfume',
          'imageUrl': 'https://images.unsplash.com/photo-1541643600914-78b084683601?w=300'
        },
        {
          'id': 'p2',
          'name': 'Bazin Rich Shoe',
          'category': 'shoes',
          'price': 35000.0,
          'quantity': 5,
          'description': 'Traditional custom leather shoes',
          'imageUrl': 'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=300'
        },
        {
          'id': 'p3',
          'name': 'Bazin Getzner Fabric',
          'category': 'fabric',
          'price': 45000.0,
          'quantity': 20,
          'description': 'High-quality Getzner bazin fabric (meters)',
          'imageUrl': 'https://images.unsplash.com/photo-1584184924103-e310d9dc82fc?w=300'
        },
        {
          'id': 'p4',
          'name': 'Velvet Kufi Cap',
          'category': 'cap',
          'price': 7500.0,
          'quantity': 15,
          'description': 'Embroidered velvet cap',
          'imageUrl': 'https://images.unsplash.com/photo-1621646733642-979f33c726f8?w=300'
        }
      ]);
      await _saveProducts();
    }

    // Load staff
    final String? staffJson = _prefs.getString('mock_staff');
    if (staffJson != null) {
      try {
        final List<dynamic> list = jsonDecode(staffJson);
        _staff.addAll(list.cast<Map<String, dynamic>>());
      } catch (_) {}
    } else {
      _staff.addAll([
        {
          'id': 's1',
          'name': 'Omar Diallo',
          'role': 'tailor',
          'pieceRate': 5000.0,
          'suitsSewnToday': 6,
          'suitsHistory': {
            'Monday': 5,
            'Tuesday': 6,
            'Wednesday': 4,
            'Thursday': 5,
            'Friday': 6,
            'Saturday': 3,
            'Sunday': 0,
          },
          'monthlySalary': 0.0,
          'phone': '76543210'
        },
        {
          'id': 's2',
          'name': 'Bakary Coulibaly',
          'role': 'tailor',
          'pieceRate': 4500.0,
          'suitsSewnToday': 4,
          'suitsHistory': {
            'Monday': 4,
            'Tuesday': 4,
            'Wednesday': 5,
            'Thursday': 3,
            'Friday': 5,
            'Saturday': 4,
            'Sunday': 0,
          },
          'monthlySalary': 0.0,
          'phone': '77665544'
        },
        {
          'id': 's3',
          'name': 'Fatoumata Traore',
          'role': 'non_tailor',
          'pieceRate': 0.0,
          'suitsSewnToday': 0,
          'suitsHistory': {},
          'monthlySalary': 120000.0,
          'phone': '78998877'
        }
      ]);
      await _saveStaff();
    }

    // Load ready to wear
    final String? rtwJson = _prefs.getString('mock_rtw');
    if (rtwJson != null) {
      try {
        final List<dynamic> list = jsonDecode(rtwJson);
        _readyToWear.addAll(list.cast<Map<String, dynamic>>());
      } catch (_) {}
    } else {
      _readyToWear.addAll([
        {
          'id': 'r1',
          'title': 'Grand Boubou Mali',
          'fabric': 'Bazin Rich Getzner',
          'price': 150000.0,
          'imageUrl': 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=300',
          'videoUrl': 'https://www.w3schools.com/html/mov_bbb.mp4',
          'description': 'Traditional Malian Grand Boubou with embroidery.'
        },
        {
          'id': 'r2',
          'title': 'Kaftan Mali Slim',
          'fabric': 'Cotton Glacé',
          'price': 85000.0,
          'imageUrl': 'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=300',
          'videoUrl': 'https://www.w3schools.com/html/mov_bbb.mp4',
          'description': 'Modern slim fit Kaftan for men.'
        }
      ]);
      await _saveRtw();
    }

    // Load appointments
    final String? apptsJson = _prefs.getString('mock_appointments');
    if (apptsJson != null) {
      try {
        final List<dynamic> list = jsonDecode(apptsJson);
        _appointments.addAll(list.cast<Map<String, dynamic>>());
      } catch (_) {}
    } else {
      _appointments.addAll([
        {
          'id': 'a1',
          'clientName': 'Mamadou Touré',
          'dateTime': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'type': 'Fitting (قياس)',
          'notes': 'Fitting for the Grand Boubou'
        },
        {
          'id': 'a2',
          'clientName': 'Awa Dembélé',
          'dateTime': DateTime.now().add(const Duration(days: 3, hours: 2)).toIso8601String(),
          'type': 'Consultation (استشارة)',
          'notes': 'Discuss fabric selection for bridal wear'
        }
      ]);
      await _saveAppointments();
    }

    // Load current user session
    final String? currentUserId = _prefs.getString('mock_current_user_id');
    if (currentUserId != null) {
      for (final u in _users) {
        if (u.id == currentUserId) {
          _currentUser = u;
          break;
        }
      }
    }

    _initialized = true;
  }

  Future<void> _saveUsers() async {
    await _prefs.setString('mock_users', jsonEncode(_users.map((u) => u.toMap()).toList()));
  }

  Future<void> _savePasswords() async {
    await _prefs.setString('mock_passwords', jsonEncode(_userPasswords));
  }

  Future<void> _saveMeasurements() async {
    await _prefs.setString('mock_measurements', jsonEncode(_measurements.map((m) => m.toMap()).toList()));
  }

  Future<void> _saveOrders() async {
    await _prefs.setString('mock_orders', jsonEncode(_orders.map((o) => o.toMap()).toList()));
  }

  Future<void> _saveNotifications() async {
    await _prefs.setString('mock_notifications', jsonEncode(_notifications.map((n) => n.toMap()).toList()));
  }

  Future<void> _saveProducts() async {
    await _prefs.setString('mock_products', jsonEncode(_products));
  }

  Future<void> _saveStaff() async {
    await _prefs.setString('mock_staff', jsonEncode(_staff));
  }

  Future<void> _saveRtw() async {
    await _prefs.setString('mock_rtw', jsonEncode(_readyToWear));
  }

  Future<void> _saveAppointments() async {
    await _prefs.setString('mock_appointments', jsonEncode(_appointments));
  }

  // Auth Operations
  Future<AppUser> signIn(String email, String password) async {
    await init();
    final cleanEmail = email.trim().toLowerCase();
    AppUser? foundUser;
    for (final u in _users) {
      if (u.email.toLowerCase() == cleanEmail) {
        foundUser = u;
        break;
      }
    }
    if (foundUser == null) {
      throw Exception('User not found');
    }
    final savedPassword = _userPasswords[cleanEmail];
    if (savedPassword != password) {
      throw Exception('Incorrect password');
    }
    currentUser = foundUser;
    return foundUser;
  }

  Future<AppUser> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await init();
    final cleanEmail = email.trim().toLowerCase();
    for (final u in _users) {
      if (u.email.toLowerCase() == cleanEmail) {
        throw Exception('Email already in use');
      }
    }
    final String uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final AppUser user = AppUser(
      id: uid,
      name: name,
      email: email,
      phone: phone,
      role: 'customer',
      createdAt: DateTime.now(),
    );
    _users.add(user);
    _userPasswords[cleanEmail] = password;
    await _saveUsers();
    await _savePasswords();
    currentUser = user;
    return user;
  }

  Future<AppUser> seedAdmin() async {
    await init();
    for (final u in _users) {
      if (u.role == 'admin') {
        currentUser = u;
        return u;
      }
    }
    final newAdmin = const AppUser(
      id: 'admin_uid',
      name: 'Shop Admin',
      email: 'admin@tailor.app',
      phone: '123456789',
      role: 'admin',
    );
    _users.add(newAdmin);
    _userPasswords['admin@tailor.app'] = 'Admin@1234';
    await _saveUsers();
    await _savePasswords();
    currentUser = newAdmin;
    return newAdmin;
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await init();
    if (currentUser == null) throw Exception('Not signed in');
    final email = currentUser!.email.toLowerCase();
    if (_userPasswords[email] != currentPassword) {
      throw Exception('Incorrect current password');
    }
    _userPasswords[email] = newPassword;
    await _savePasswords();
  }

  // Customer Operations
  List<AppUser> getCustomers() {
    return _users.where((u) => u.role == 'customer').toList();
  }

  AppUser? getCustomer(String uid) {
    for (final u in _users) {
      if (u.id == uid) return u;
    }
    return null;
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    required String phone,
    String? profilePhotoUrl,
  }) async {
    await init();
    final index = _users.indexWhere((u) => u.id == uid);
    if (index != -1) {
      _users[index] = _users[index].copyWith(
        name: name,
        phone: phone,
        profilePhotoUrl: profilePhotoUrl,
      );
      await _saveUsers();
      if (currentUser?.id == uid) {
        currentUser = _users[index];
      }
    }
  }

  // Measurements
  Measurements getMeasurements(String uid) {
    for (final m in _measurements) {
      if (m.userId == uid) return m;
    }
    return Measurements.empty(uid);
  }

  Future<void> saveMeasurements(Measurements m) async {
    await init();
    final index = _measurements.indexWhere((item) => item.userId == m.userId);
    if (index != -1) {
      _measurements[index] = m;
    } else {
      _measurements.add(m);
    }
    await _saveMeasurements();
  }

  // Orders
  List<TailoringOrder> getCustomerOrders(String customerId) {
    final list = _orders.where((o) => o.customerId == customerId).toList();
    list.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  List<TailoringOrder> getAllOrders() {
    final list = List<TailoringOrder>.from(_orders);
    list.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  TailoringOrder? getOrder(String orderId) {
    for (final o in _orders) {
      if (o.id == orderId) return o;
    }
    return null;
  }

  Future<TailoringOrder> createOrder(TailoringOrder order) async {
    await init();
    final String id = order.id.isEmpty ? 'order_${DateTime.now().millisecondsSinceEpoch}' : order.id;
    final List<StatusEvent> history = order.statusHistory.isNotEmpty 
        ? order.statusHistory 
        : [StatusEvent(status: order.status, changedAt: DateTime.now(), changedBy: currentUser?.name ?? 'System', note: 'Order created')];
    final TailoringOrder withId = TailoringOrder(
      id: id,
      customerId: order.customerId,
      customerName: order.customerName,
      garmentType: order.garmentType,
      fabricDescription: order.fabricDescription,
      fabricPhotoUrl: order.fabricPhotoUrl,
      styleReferencePhotoUrl: order.styleReferencePhotoUrl,
      specialInstructions: order.specialInstructions,
      deliveryDate: order.deliveryDate,
      price: order.price,
      status: order.status,
      statusHistory: history,
      adminNotes: order.adminNotes,
      measurementsSnapshot: order.measurementsSnapshot,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _orders.add(withId);
    await _saveOrders();
    return withId;
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
    required String adminUserId,
    String note = '',
    double? price,
    String? adminNotes,
  }) async {
    await init();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final order = _orders[index];
      String changerName = 'Admin';
      for (final u in _users) {
        if (u.id == adminUserId) {
          changerName = u.name;
          break;
        }
      }
      final List<StatusEvent> history = List.from(order.statusHistory)
        ..add(StatusEvent(
          status: newStatus,
          changedAt: DateTime.now(),
          changedBy: changerName,
          note: note,
        ));
      
      _orders[index] = order.copyWith(
        status: newStatus,
        statusHistory: history,
        price: price ?? order.price,
        adminNotes: adminNotes ?? order.adminNotes,
      );
      await _saveOrders();
    }
  }

  Future<void> updateOrderPriceAndNotes({
    required String orderId,
    double? price,
    String? adminNotes,
  }) async {
    await init();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        price: price ?? _orders[index].price,
        adminNotes: adminNotes ?? _orders[index].adminNotes,
      );
      await _saveOrders();
    }
  }

  Future<void> updateOrderImageUrls({
    required String orderId,
    String? fabricUrl,
    String? styleUrl,
  }) async {
    await init();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        fabricPhotoUrl: fabricUrl ?? _orders[index].fabricPhotoUrl,
        styleReferencePhotoUrl: styleUrl ?? _orders[index].styleReferencePhotoUrl,
      );
      await _saveOrders();
    }
  }

  Future<void> deleteOrder(String orderId) async {
    await init();
    _orders.removeWhere((o) => o.id == orderId);
    await _saveOrders();
  }

  // Notifications
  List<AppNotification> getUserNotifications(String uid) {
    final list = _notifications.where((n) => n.recipientId == uid).toList();
    list.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  Future<AppNotification> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required String senderId,
    String? orderId,
  }) async {
    await init();
    final n = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      recipientId: recipientId,
      title: title,
      body: body,
      isRead: false,
      senderId: senderId,
      orderId: orderId,
      createdAt: DateTime.now(),
    );
    _notifications.add(n);
    await _saveNotifications();
    return n;
  }

  Future<int> broadcast({
    required List<String> recipientIds,
    required String title,
    required String body,
    required String senderId,
    String? orderId,
  }) async {
    await init();
    for (final recipientId in recipientIds) {
      await sendNotification(
        recipientId: recipientId,
        title: title,
        body: body,
        senderId: senderId,
        orderId: orderId,
      );
    }
    return recipientIds.length;
  }

  Future<void> markNotificationRead(String id) async {
    await init();
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = AppNotification(
        id: _notifications[index].id,
        recipientId: _notifications[index].recipientId,
        title: _notifications[index].title,
        body: _notifications[index].body,
        isRead: true,
        orderId: _notifications[index].orderId,
        senderId: _notifications[index].senderId,
        createdAt: _notifications[index].createdAt,
      );
      await _saveNotifications();
    }
  }

  Future<void> markAllNotificationsRead(String uid) async {
    await init();
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].recipientId == uid) {
        _notifications[i] = AppNotification(
          id: _notifications[i].id,
          recipientId: _notifications[i].recipientId,
          title: _notifications[i].title,
          body: _notifications[i].body,
          isRead: true,
          orderId: _notifications[i].orderId,
          senderId: _notifications[i].senderId,
          createdAt: _notifications[i].createdAt,
        );
      }
    }
    await _saveNotifications();
  }

  Future<void> deleteNotification(String id) async {
    await init();
    _notifications.removeWhere((n) => n.id == id);
    await _saveNotifications();
  }

  // --- New Mali Custom Modules Operations ---

  // Products
  Future<List<Map<String, dynamic>>> getProducts() async {
    await init();
    return List<Map<String, dynamic>>.from(_products);
  }

  Future<void> saveProduct(Map<String, dynamic> p) async {
    await init();
    final idx = _products.indexWhere((x) => x['id'] == p['id']);
    if (idx != -1) {
      _products[idx] = p;
    } else {
      _products.add(p);
    }
    await _saveProducts();
  }

  Future<void> deleteProduct(String id) async {
    await init();
    _products.removeWhere((x) => x['id'] == id);
    await _saveProducts();
  }

  // Staff
  Future<List<Map<String, dynamic>>> getStaff() async {
    await init();
    return List<Map<String, dynamic>>.from(_staff);
  }

  Future<void> saveStaffMember(Map<String, dynamic> s) async {
    await init();
    final idx = _staff.indexWhere((x) => x['id'] == s['id']);
    if (idx != -1) {
      _staff[idx] = s;
    } else {
      _staff.add(s);
    }
    await _saveStaff();
  }

  Future<void> deleteStaffMember(String id) async {
    await init();
    _staff.removeWhere((x) => x['id'] == id);
    await _saveStaff();
  }

  Future<void> recordSuits(String id, String day, int count) async {
    await init();
    final idx = _staff.indexWhere((x) => x['id'] == id);
    if (idx != -1) {
      final s = Map<String, dynamic>.from(_staff[idx]);
      final history = Map<String, dynamic>.from(s['suitsHistory'] ?? {});
      history[day] = count;
      s['suitsHistory'] = history;
      s['suitsSewnToday'] = count;
      _staff[idx] = s;
      await _saveStaff();
    }
  }

  // Prêt-à-porter
  Future<List<Map<String, dynamic>>> getRtw() async {
    await init();
    return List<Map<String, dynamic>>.from(_readyToWear);
  }

  Future<void> saveRtwItem(Map<String, dynamic> r) async {
    await init();
    final idx = _readyToWear.indexWhere((x) => x['id'] == r['id']);
    if (idx != -1) {
      _readyToWear[idx] = r;
    } else {
      _readyToWear.add(r);
    }
    await _saveRtw();
  }

  Future<void> deleteRtwItem(String id) async {
    await init();
    _readyToWear.removeWhere((x) => x['id'] == id);
    await _saveRtw();
  }

  // Appointments
  Future<List<Map<String, dynamic>>> getAppointments() async {
    await init();
    return List<Map<String, dynamic>>.from(_appointments);
  }

  Future<void> saveAppointment(Map<String, dynamic> a) async {
    await init();
    final idx = _appointments.indexWhere((x) => x['id'] == a['id']);
    if (idx != -1) {
      _appointments[idx] = a;
    } else {
      _appointments.add(a);
    }
    await _saveAppointments();
  }

  Future<void> deleteAppointment(String id) async {
    await init();
    _appointments.removeWhere((x) => x['id'] == id);
    await _saveAppointments();
  }
}
