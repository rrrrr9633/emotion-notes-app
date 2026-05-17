import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  final ApiService _apiService = ApiService();
  
  bool _isLoggedIn = false;
  String? _userId;
  String? _username;
  String? _partnerId;
  bool _isPartnerBound = false;

  AuthProvider(this._prefs) {
    _loadUserData();
  }

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get username => _username;
  String? get partnerId => _partnerId;
  bool get isPartnerBound => _isPartnerBound;

  // 加载本地存储的用户数据
  Future<void> _loadUserData() async {
    _isLoggedIn = _prefs.getBool('isLoggedIn') ?? false;
    _userId = _prefs.getString('userId');
    _username = _prefs.getString('username');
    _partnerId = _prefs.getString('partnerId');
    _isPartnerBound = _prefs.getBool('isPartnerBound') ?? false;
    notifyListeners();
  }

  // 注册
  Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      final response = await _apiService.register(username, password);
      if (response['success']) {
        await _saveUserData(
          response['userId'],
          username,
          null,
          false,
        );
        return {'success': true};
      }
      return {'success': false, 'message': response['message']};
    } catch (e) {
      return {'success': false, 'message': '注册失败: $e'};
    }
  }

  // 登录
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _apiService.login(username, password);
      if (response['success']) {
        await _saveUserData(
          response['userId'],
          username,
          response['partnerId'],
          response['isPartnerBound'] ?? false,
        );
        return {'success': true};
      }
      return {'success': false, 'message': response['message']};
    } catch (e) {
      return {'success': false, 'message': '登录失败: $e'};
    }
  }

  // 发送绑定请求
  Future<Map<String, dynamic>> sendBindRequest(String partnerUsername) async {
    try {
      final response = await _apiService.sendBindRequest(_userId!, partnerUsername);
      return response;
    } catch (e) {
      return {'success': false, 'message': '发送绑定请求失败: $e'};
    }
  }

  // 获取待处理的绑定请求
  Future<Map<String, dynamic>> getPendingBindRequests() async {
    try {
      final response = await _apiService.getPendingBindRequests(_userId!);
      return response;
    } catch (e) {
      return {'success': false, 'message': '获取绑定请求失败: $e'};
    }
  }

  // 接受绑定请求
  Future<Map<String, dynamic>> acceptBindRequest(String requestId) async {
    try {
      final response = await _apiService.acceptBindRequest(requestId);
      if (response['success']) {
        _partnerId = response['partnerId'];
        _isPartnerBound = true;
        await _prefs.setString('partnerId', _partnerId!);
        await _prefs.setBool('isPartnerBound', true);
        notifyListeners();
      }
      return response;
    } catch (e) {
      return {'success': false, 'message': '接受绑定失败: $e'};
    }
  }

  // 保存用户数据
  Future<void> _saveUserData(String userId, String username, String? partnerId, bool isPartnerBound) async {
    _isLoggedIn = true;
    _userId = userId;
    _username = username;
    _partnerId = partnerId;
    _isPartnerBound = isPartnerBound;

    await _prefs.setBool('isLoggedIn', true);
    await _prefs.setString('userId', userId);
    await _prefs.setString('username', username);
    if (partnerId != null) {
      await _prefs.setString('partnerId', partnerId);
    }
    await _prefs.setBool('isPartnerBound', isPartnerBound);
    
    notifyListeners();
  }

  // 登出
  Future<void> logout() async {
    _isLoggedIn = false;
    _userId = null;
    _username = null;
    _partnerId = null;
    _isPartnerBound = false;

    await _prefs.clear();
    notifyListeners();
  }
}
