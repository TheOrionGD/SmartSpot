import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/family_group.dart';
import '../services/api_service.dart';

class FamilyGroupProvider extends ChangeNotifier {
  static const _kStorageKey = 'family_groups_v1';
  final ApiService _apiService = ApiService.instance;

  List<FamilyGroup> _groups = [];
  bool _isLoaded = false;

  List<FamilyGroup> get groups => _groups;
  bool get isLoaded => _isLoaded;

  FamilyGroupProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _groups = list
            .map((e) => FamilyGroup.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _groups = [];
      }
    }

    try {
      final remoteGroups = await _apiService.fetchGroups();
      if (remoteGroups.isNotEmpty) {
        _groups = remoteGroups;
        await _persist();
      }
    } catch (e) {
      debugPrint('Skipping remote group fetch: $e');
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_groups.map((g) => g.toJson()).toList());
    await prefs.setString(_kStorageKey, raw);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  FamilyGroup? groupById(String? id) {
    if (id == null) return null;
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<FamilyGroup> createGroup(String name) async {
    FamilyGroup group;
    try {
      group = await _apiService.createGroup(name);
    } catch (e) {
      debugPrint('Creating group locally: $e');
      group = FamilyGroup(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        memberNames: const [],
        inviteCode: _generateInviteCode(),
        createdAt: DateTime.now(),
      );
    }

    _groups = [..._groups, group];
    notifyListeners();
    await _persist();
    return group;
  }

  Future<FamilyGroup> joinGroup(String inviteCode) async {
    final group = await _apiService.joinGroup(inviteCode);
    _groups = _groups.where((g) => g.id != group.id).toList()..add(group);
    notifyListeners();
    await _persist();
    return group;
  }

  Future<void> addMember(String groupId, String memberName) async {
    try {
      final updated = await _apiService.addGroupMember(groupId, memberName);
      _groups = _groups.map((g) => g.id == groupId ? updated : g).toList();
    } catch (e) {
      debugPrint('Updating member locally: $e');
      _groups = _groups.map((g) {
        if (g.id != groupId) return g;
        if (g.memberNames.contains(memberName)) return g;
        return g.copyWith(memberNames: [...g.memberNames, memberName]);
      }).toList();
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removeMember(String groupId, String memberName) async {
    try {
      await _apiService.removeGroupMember(groupId, memberName);
    } catch (e) {
      debugPrint('Removing member locally: $e');
    }
    _groups = _groups.map((g) {
      if (g.id != groupId) return g;
      return g.copyWith(
        memberNames: g.memberNames.where((m) => m != memberName).toList(),
      );
    }).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      await _apiService.deleteGroup(groupId);
    } catch (e) {
      debugPrint('Deleting group locally: $e');
    }
    _groups = _groups.where((g) => g.id != groupId).toList();
    notifyListeners();
    await _persist();
  }
}
