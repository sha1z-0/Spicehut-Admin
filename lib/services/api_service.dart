import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

class ApiService {
  // Backend Configuration - Hardcoded Production URLs
  static const String baseUrl = 'https://spicehut-admin.vercel.app/api';
  static const String socketUrl = 'https://spicehut-admin.vercel.app';
  
  static bool useMock = true; // Using real backend with MongoDB
  static final _MockApi _mock = _MockApi();

  // Get JWT token from SharedPreferences
  static Future<String?> _getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Build headers with JWT token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getJwtToken();
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // PRODUCTION (Vercel)
  // static const String baseUrl = 'https://spicehut-backend.vercel.app/api';

  static Future<dynamic> post(
      String endpoint, Map<String, dynamic> body) async {
    if (useMock) {
      return _mock.post(endpoint, body);
    }
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        // Handle specific status codes with user-friendly messages
        if (response.statusCode == 401) {
          // Try to get message from response, fallback to user-friendly message
          try {
            final errorData = jsonDecode(response.body);
            final errorMessage = errorData['message'] ?? 'Wrong email or password';
            throw Exception(errorMessage);
          } catch (e) {
            if (e is Exception && e.toString().contains('Wrong')) {
              rethrow;
            }
            throw Exception('Wrong email or password');
          }
        }
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Request failed';
          throw Exception(errorMessage);
        } catch (e) {
          if (e is Exception && !e.toString().contains('FormatException')) {
            rethrow;
          }
          throw Exception('Request failed with status: ${response.statusCode}');
        }
      }
    } catch (e) {
      LoggerService.error('POST request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }

  static Future<dynamic> get(String endpoint) async {
    if (useMock) {
      return _mock.get(endpoint);
    }
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.error('GET request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    if (useMock) {
      return _mock.put(endpoint, body);
    }
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.error('PUT request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    if (useMock) {
      return _mock.patch(endpoint, body);
    }
    try {
      final headers = await _getHeaders();
      LoggerService.debug('PATCH $baseUrl$endpoint', 'ApiService');
      LoggerService.debug('Headers: ${headers.keys.join(', ')}', 'ApiService');
      LoggerService.debug('Body keys: ${body.keys.join(', ')}', 'ApiService');
      
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );

      LoggerService.debug('Response status: ${response.statusCode}', 'ApiService');
      LoggerService.debug('Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}', 'ApiService');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        // Try to parse error message from response body
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Failed to update: ${response.statusCode}';
          LoggerService.debug('Backend error: $errorMessage', 'ApiService');
          throw Exception(errorMessage);
        } catch (e) {
          if (e.toString().contains('message')) {
            rethrow;
          }
          throw Exception('Failed to update: ${response.statusCode}');
        }
      }
    } catch (e) {
      LoggerService.error('PATCH request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }

  static Future<void> delete(String endpoint) async {
    if (useMock) {
      await _mock.delete(endpoint);
      return;
    }
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      } else {
        throw Exception('Failed to delete: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.error('DELETE request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }
}

class _MockApi {
  final List<Map<String, dynamic>> _users = [
    {
      '_id': 'u1',
      'username': 'admin@spicehut.com',
      'role': 'admin',
      'location': ''
    },
    {
      '_id': 'u2',
      'username': 'manager@branch-a.com',
      'role': 'manager',
      'location': 'Branch A'
    },
  ];

  final List<Map<String, dynamic>> _menu = [
    {
      '_id': 'm1',
      'name': 'Chees Burger',
      'description': 'Juicy beef patty with cheese',
      'price': 8.99,
      'category': 'Main',
      'imageUrl': ''
    },
    {
      '_id': 'm2',
      'name': 'Pizza Peperoni',
      'description': 'Classic pepperoni pizza',
      'price': 12.5,
      'category': 'Main',
      'imageUrl': ''
    },
    {
      '_id': 'm3',
      'name': 'Caesar Salad',
      'description': 'Crisp romaine, parmesan, croutons',
      'price': 6.25,
      'category': 'Salad',
      'imageUrl': ''
    },
  ];

  final List<Map<String, dynamic>> _tables = [
    {'_id': 't1', 'number': 1, 'seats': 4, 'status': 'available'},
    {'_id': 't2', 'number': 2, 'seats': 4, 'status': 'available'},
    {'_id': 't3', 'number': 3, 'seats': 4, 'status': 'available'},
  ];

  final List<Map<String, dynamic>> _orders = [];

  int _orderSeq = 1000;
  _MockApi() {
    _seedOrders();
  }

  void _seedOrders() {
    final now = DateTime.now();
    final samples = [
      {
        '_id': 'o$_orderSeq',
        'orderNumber': '#$_orderSeq',
        'dateTime': now.subtract(const Duration(minutes: 15)).toIso8601String(),
        'status': 'pending',
        'items': [
          {
            'name': 'Chees Burger',
            'description': '',
            'price': 8.99,
            'quantity': 2,
            'imageUrl': ''
          },
          {
            'name': 'Caesar Salad',
            'description': '',
            'price': 6.25,
            'quantity': 1,
            'imageUrl': ''
          },
        ],
        'totalAmount': 8.99 * 2 + 6.25,
        'location': 'Branch A',
        'type': 'online',
        'customerAvatar': '👤',
      },
      {
        '_id': 'o${_orderSeq + 1}',
        'orderNumber': '#${_orderSeq + 1}',
        'dateTime': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'status': 'accepted',
        'items': [
          {
            'name': 'Pizza Peperoni',
            'description': '',
            'price': 12.5,
            'quantity': 1,
            'imageUrl': ''
          },
        ],
        'totalAmount': 12.5,
        'location': 'Branch A',
        'type': 'online',
        'customerAvatar': '👤',
      },
    ];
    _orders.addAll(samples);
    _orderSeq += 2;
  }

  Map<String, String> _parseQuery(String endpoint) {
    final qIndex = endpoint.indexOf('?');
    if (qIndex == -1) return {};
    final query = endpoint.substring(qIndex + 1);
    final parts = query.split('&');
    final map = <String, String>{};
    for (final p in parts) {
      final kv = p.split('=');
      if (kv.length == 2) map[kv[0]] = Uri.decodeComponent(kv[1]);
    }
    return map;
  }

  String _pathOnly(String endpoint) {
    final qIndex = endpoint.indexOf('?');
    return qIndex == -1 ? endpoint : endpoint.substring(0, qIndex);
  }

  Future<dynamic> get(String endpoint) async {
    final path = _pathOnly(endpoint);
    final query = _parseQuery(endpoint);

    if (path == '/users') {
      return List<Map<String, dynamic>>.from(_users);
    }

    if (path == '/menu') {
      return List<Map<String, dynamic>>.from(_menu);
    }

    if (path == '/tables') {
      return List<Map<String, dynamic>>.from(_tables);
    }

    if (path == '/orders') {
      final loc = query['location'];
      final list = _orders
          .where(
              (o) => loc == null || loc.isEmpty || (o['location'] ?? '') == loc)
          .toList();
      return list;
    }

    if (path == '/analytics') {
      if (query['type'] == 'daily_breakdown') {
        return [
          {'day': 'Mon', 'afternoonOrders': 12, 'nightOrders': 18},
          {'day': 'Tue', 'afternoonOrders': 9, 'nightOrders': 20},
          {'day': 'Wed', 'afternoonOrders': 15, 'nightOrders': 16},
          {'day': 'Thu', 'afternoonOrders': 11, 'nightOrders': 14},
          {'day': 'Fri', 'afternoonOrders': 20, 'nightOrders': 28},
          {'day': 'Sat', 'afternoonOrders': 25, 'nightOrders': 35},
          {'day': 'Sun', 'afternoonOrders': 10, 'nightOrders': 12},
        ];
      }

      final period = (query['period'] ?? 'monthly');
      final data = {
        'perDayIncome': 12145.0,
        'totalIncome': 342247.0,
        'perDayChangePercent': -2.4,
        'totalIncomeChangePercent': 6.5,
        'chartData': period == 'monthly'
            ? [
                {'month': 'Jan', 'income': 42000.0},
                {'month': 'Feb', 'income': 65000.0},
                {'month': 'Mar', 'income': 82000.0},
                {'month': 'Apr', 'income': 76000.0},
              ]
            : [
                {'month': 'W1', 'income': 15000.0},
                {'month': 'W2', 'income': 18000.0},
                {'month': 'W3', 'income': 22000.0},
                {'month': 'W4', 'income': 19000.0},
              ],
      };
      return data;
    }

    throw Exception('Mock GET not implemented for $endpoint');
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final path = _pathOnly(endpoint);

    if (path == '/auth/login' || path == '/auth/admin-login') {
      final email = (body['email'] ?? body['username'] ?? '').toString();
      final isSuperAdmin = email.contains('superadmin');
      return {
        'success': true,
        'data': {
          'adminId': 'mock-admin-id',
          'email': email,
          'name': isSuperAdmin ? 'Super Admin' : 'Branch Admin',
          'role': isSuperAdmin ? 'superAdmin' : 'branchAdmin',
          'branch': isSuperAdmin ? null : 'Comox',
              'branches':
                isSuperAdmin ? ['Comox', 'Port Alberni', 'Fort Saskatchewan'] : ['Comox'],
        }
      };
    }

    if (path == '/auth/register') {
      final newUser = {
        '_id': 'u${_users.length + 1}',
        'username': body['username'],
        'role': body['role'] ?? 'manager',
        'location': body['location'] ?? 'Branch A',
      };
      _users.add(newUser);
      return newUser;
    }

    if (path == '/menu') {
      final newItem = {
        '_id': 'm${_menu.length + 1}',
        'name': body['name'],
        'description': body['description'] ?? '',
        'price': (body['price'] as num).toDouble(),
        'category': body['category'] ?? 'Main',
        'imageUrl': body['imageUrl'] ?? '',
      };
      _menu.add(newItem);
      return newItem;
    }

    if (path == '/tables') {
      final newTable = {
        '_id': 't${_tables.length + 1}',
        'number': body['number'] ?? (_tables.length + 1),
        'seats': body['seats'] ?? 4,
        'status': body['status'] ?? 'available',
      };
      _tables.add(newTable);
      return newTable;
    }

    if (path == '/orders') {
      _orderSeq += 1;
      final items = (body['items'] as List<dynamic>? ?? [])
          .map((e) => {
                'name': e['name'],
                'description': e['description'] ?? '',
                'price': (e['price'] as num).toDouble(),
                'quantity': (e['quantity'] as num?)?.toInt() ?? 1,
                'imageUrl': e['imageUrl'],
              })
          .toList();
      final total = (body['totalAmount'] as num?)?.toDouble() ??
          items.fold<double>(0,
              (s, it) => s + (it['price'] as double) * (it['quantity'] as int));
      final order = {
        '_id': 'o$_orderSeq',
        'orderNumber': '#$_orderSeq',
        'dateTime': DateTime.now().toIso8601String(),
        'status': body['status'] ?? 'pending',
        'items': items,
        'totalAmount': total,
        'location': body['location'] ?? 'Branch A',
        'type': body['type'] ?? 'online',
        'customerAvatar': '👤',
      };
      _orders.add(order);
      return order;
    }

    throw Exception('Mock POST not implemented for $endpoint');
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final path = _pathOnly(endpoint);

    if (path.startsWith('/orders/')) {
      final id = path.split('/').last;
      final idx = _orders.indexWhere((o) => o['_id'] == id);
      if (idx != -1) {
        _orders[idx] = {
          ..._orders[idx],
          ...body,
        };
        return _orders[idx];
      }
      throw Exception('Order not found');
    }

    if (path.startsWith('/menu/')) {
      final id = path.split('/').last;
      final idx = _menu.indexWhere((m) => m['_id'] == id);
      if (idx != -1) {
        _menu[idx] = {
          ..._menu[idx],
          'name': body['name'] ?? _menu[idx]['name'],
          'description': body['description'] ?? _menu[idx]['description'],
          'price': (body['price'] as num?)?.toDouble() ?? _menu[idx]['price'],
          'category': body['category'] ?? _menu[idx]['category'],
          'imageUrl': body['imageUrl'] ?? _menu[idx]['imageUrl'],
        };
        return _menu[idx];
      }
      throw Exception('Menu item not found');
    }

    throw Exception('Mock PUT not implemented for $endpoint');
  }

  Future<void> delete(String endpoint) async {
    final path = _pathOnly(endpoint);

    if (path.startsWith('/orders/')) {
      final id = path.split('/').last;
      _orders.removeWhere((o) => o['_id'] == id);
      return;
    }

    if (path.startsWith('/menu/')) {
      final id = path.split('/').last;
      _menu.removeWhere((m) => m['_id'] == id);
      return;
    }

    if (path.startsWith('/tables/')) {
      final id = path.split('/').last;
      _tables.removeWhere((t) => t['_id'] == id);
      return;
    }

    if (path.startsWith('/users')) {
      final q = _parseQuery(endpoint);
      final id = q['id'];
      if (id != null) {
        _users.removeWhere((u) => u['_id'] == id);
        return;
      }
    }

    throw Exception('Mock DELETE not implemented for $endpoint');
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final path = _pathOnly(endpoint);

    if (path.startsWith('/users/')) {
      final id = path.split('/').last;
      final idx = _users.indexWhere((u) => u['_id'] == id);
      if (idx != -1) {
        _users[idx] = {
          ..._users[idx],
          ...body,
        };
        return _users[idx];
      }
      throw Exception('User not found');
    }

    if (path.startsWith('/orders/')) {
      final id = path.split('/').last;
      final idx = _orders.indexWhere((o) => o['_id'] == id);
      if (idx != -1) {
        _orders[idx] = {
          ..._orders[idx],
          ...body,
        };
        return _orders[idx];
      }
      throw Exception('Order not found');
    }

    throw Exception('Mock PATCH not implemented for $endpoint');
  }
}
