import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/reminder.dart';
import '../models/favorite_location.dart';
import '../models/family_group.dart';
import '../models/location_visit.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String get _baseUrl => AuthService.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    dynamic body,
  }) async {
    try {
      final headers = await _headers();
      var uri = Uri.parse('$_baseUrl$path');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      http.Response response;
      final encodedBody = body != null ? jsonEncode(body) : null;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 12));
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 12));
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 12));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 12));
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }

      if (response.statusCode == 204) return null;

      final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMsg = (responseData is Map && responseData.containsKey('error'))
            ? responseData['error'].toString()
            : 'Request failed with status ${response.statusCode}';
        throw ApiException(errorMsg, statusCode: response.statusCode);
      }

      return responseData;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('API network request failed ($method $path): $e');
      throw ApiException('Unable to connect to SmartSpot backend server ($e)');
    }
  }

  // ---------------------------------------------------------------------------
  // Reminders Endpoints
  // ---------------------------------------------------------------------------
  Future<List<Reminder>> fetchReminders({
    String? category,
    bool? isCompleted,
    bool? isArchived,
    String? search,
  }) async {
    final query = <String, String>{};
    if (category != null) query['category'] = category;
    if (isCompleted != null) query['isCompleted'] = isCompleted.toString();
    if (isArchived != null) query['isArchived'] = isArchived.toString();
    if (search != null && search.isNotEmpty) query['search'] = search;

    final data = await _send('GET', '/api/reminders', queryParameters: query) as List?;
    if (data == null) return [];
    return data.map((item) => Reminder.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<Reminder> getReminder(String id) async {
    final data = await _send('GET', '/api/reminders/$id') as Map;
    return Reminder.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Reminder> createReminder(Reminder reminder) async {
    final data = await _send('POST', '/api/reminders', body: reminder.toMap()) as Map;
    return Reminder.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Reminder> updateReminder(Reminder reminder) async {
    final data = await _send('PUT', '/api/reminders/${reminder.id}', body: reminder.toMap()) as Map;
    return Reminder.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> deleteReminder(String id) async {
    await _send('DELETE', '/api/reminders/$id');
  }

  Future<Reminder> toggleComplete(String id, {bool? isCompleted}) async {
    final data = await _send('PATCH', '/api/reminders/$id/complete', body: {
      if (isCompleted != null) 'isCompleted': isCompleted,
    }) as Map;
    return Reminder.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Reminder> toggleArchive(String id, {bool? isArchived}) async {
    final data = await _send('PATCH', '/api/reminders/$id/archive', body: {
      if (isArchived != null) 'isArchived': isArchived,
    }) as Map;
    return Reminder.fromMap(Map<String, dynamic>.from(data));
  }

  Future<List<Reminder>> syncReminders(List<Reminder> localReminders) async {
    final payload = {
      'reminders': localReminders.map((r) => r.toMap()).toList(),
    };
    final data = await _send('POST', '/api/reminders/sync', body: payload) as Map?;
    if (data == null || !data.containsKey('reminders')) return [];
    final list = data['reminders'] as List;
    return list.map((item) => Reminder.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  // ---------------------------------------------------------------------------
  // Favorites Endpoints
  // ---------------------------------------------------------------------------
  Future<List<FavoriteLocation>> fetchFavorites() async {
    final data = await _send('GET', '/api/favorites') as List?;
    if (data == null) return [];
    return data.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return FavoriteLocation(
        id: map['id'] ?? '',
        label: map['label'] ?? '',
        latitude: (map['latitude'] ?? 0.0).toDouble(),
        longitude: (map['longitude'] ?? 0.0).toDouble(),
        address: map['address'],
        icon: map['icon'] ?? '📍',
      );
    }).toList();
  }

  Future<FavoriteLocation> createFavorite(FavoriteLocation favorite) async {
    final body = {
      'id': favorite.id,
      'label': favorite.label,
      'latitude': favorite.latitude,
      'longitude': favorite.longitude,
      'address': favorite.address,
      'icon': favorite.icon,
    };
    final data = await _send('POST', '/api/favorites', body: body) as Map;
    return FavoriteLocation(
      id: data['id'] ?? favorite.id,
      label: data['label'] ?? favorite.label,
      latitude: (data['latitude'] ?? favorite.latitude).toDouble(),
      longitude: (data['longitude'] ?? favorite.longitude).toDouble(),
      address: data['address'],
      icon: data['icon'] ?? favorite.icon,
    );
  }

  Future<FavoriteLocation> updateFavorite(FavoriteLocation favorite) async {
    final body = {
      'label': favorite.label,
      'latitude': favorite.latitude,
      'longitude': favorite.longitude,
      'address': favorite.address,
      'icon': favorite.icon,
    };
    final data = await _send('PUT', '/api/favorites/${favorite.id}', body: body) as Map;
    return FavoriteLocation(
      id: data['id'] ?? favorite.id,
      label: data['label'] ?? favorite.label,
      latitude: (data['latitude'] ?? favorite.latitude).toDouble(),
      longitude: (data['longitude'] ?? favorite.longitude).toDouble(),
      address: data['address'],
      icon: data['icon'] ?? favorite.icon,
    );
  }

  Future<void> deleteFavorite(String id) async {
    await _send('DELETE', '/api/favorites/$id');
  }

  // ---------------------------------------------------------------------------
  // Family / Shared Groups Endpoints
  // ---------------------------------------------------------------------------
  Future<List<FamilyGroup>> fetchGroups() async {
    final data = await _send('GET', '/api/groups') as List?;
    if (data == null) return [];
    return data.map((item) => FamilyGroup.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<FamilyGroup> createGroup(String name) async {
    final data = await _send('POST', '/api/groups', body: {'name': name}) as Map;
    return FamilyGroup.fromJson(Map<String, dynamic>.from(data));
  }

  Future<FamilyGroup> updateGroup(String groupId, String name) async {
    final data = await _send('PUT', '/api/groups/$groupId', body: {'name': name}) as Map;
    return FamilyGroup.fromJson(Map<String, dynamic>.from(data));
  }

  Future<FamilyGroup> joinGroup(String inviteCode) async {
    final data = await _send('POST', '/api/groups/join', body: {'inviteCode': inviteCode}) as Map;
    return FamilyGroup.fromJson(Map<String, dynamic>.from(data));
  }

  Future<FamilyGroup> addGroupMember(String groupId, String memberName) async {
    final data = await _send('POST', '/api/groups/$groupId/members', body: {'memberName': memberName}) as Map;
    return FamilyGroup.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> removeGroupMember(String groupId, String memberName) async {
    await _send('DELETE', '/api/groups/$groupId/members/${Uri.encodeComponent(memberName)}');
  }

  Future<void> deleteGroup(String groupId) async {
    await _send('DELETE', '/api/groups/$groupId');
  }

  // ---------------------------------------------------------------------------
  // Location Visits Endpoints
  // ---------------------------------------------------------------------------
  Future<void> logVisit(LocationVisit visit) async {
    await _send('POST', '/api/visits', body: visit.toMap());
  }

  Future<List<LocationVisit>> fetchVisits() async {
    final data = await _send('GET', '/api/visits') as List?;
    if (data == null) return [];
    return data.map((item) => LocationVisit.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  // ---------------------------------------------------------------------------
  // Analytics & Statistics Endpoints
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> fetchAnalytics() async {
    final data = await _send('GET', '/api/analytics/statistics') as Map?;
    return data != null ? Map<String, dynamic>.from(data) : {};
  }
}
