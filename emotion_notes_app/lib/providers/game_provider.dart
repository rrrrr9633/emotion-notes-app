import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class GameProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  final ApiService _apiService = ApiService();
  
  bool _isGameCompleted = false;
  int _currentLevel = 0;
  String? _userId;

  GameProvider(this._prefs) {
    _loadLocalGameProgress();
  }

  bool get isGameCompleted => _isGameCompleted;
  int get currentLevel => _currentLevel;

  // 设置用户ID并从后端加载游戏进度
  Future<void> setUserId(String userId) async {
    _userId = userId;
    await loadGameProgressFromServer();
  }

  // 从本地加载游戏进度（仅作为缓存）
  Future<void> _loadLocalGameProgress() async {
    _isGameCompleted = _prefs.getBool('isGameCompleted') ?? false;
    _currentLevel = _prefs.getInt('currentLevel') ?? 0;
    
    print('[GameProvider] 从本地加载游戏进度:');
    print('  - isGameCompleted: $_isGameCompleted');
    print('  - currentLevel: $_currentLevel');
    
    notifyListeners();
  }

  // 从服务器加载游戏进度
  Future<void> loadGameProgressFromServer() async {
    if (_userId == null) {
      print('[GameProvider] userId为空，无法加载游戏进度');
      return;
    }
    
    try {
      print('[GameProvider] 正在从服务器加载游戏进度...');
      final result = await _apiService.getGameProgress(_userId!);
      
      print('[GameProvider] API响应: $result');
      
      if (result['success'] == true) {
        _isGameCompleted = result['onboarding_completed'] ?? false;
        _currentLevel = result['current_level'] ?? 0;
        
        print('[GameProvider] 游戏进度加载成功:');
        print('  - isGameCompleted: $_isGameCompleted');
        print('  - currentLevel: $_currentLevel');
        
        // 同步到本地缓存
        await _prefs.setBool('isGameCompleted', _isGameCompleted);
        await _prefs.setInt('currentLevel', _currentLevel);
        
        notifyListeners();
      } else {
        print('[GameProvider] API返回失败: ${result['message']}');
        // API失败时使用本地缓存
        await _loadLocalGameProgress();
      }
    } catch (e) {
      print('[GameProvider] 加载游戏进度失败: $e');
      // 出错时使用本地缓存
      await _loadLocalGameProgress();
    }
  }

  // 完成关卡
  Future<void> completeLevel(int level) async {
    _currentLevel = level + 1;
    
    // 保存到本地
    await _prefs.setInt('currentLevel', _currentLevel);
    
    // 保存到服务器
    if (_userId != null) {
      await _apiService.updateLevel(_userId!, _currentLevel);
    }
    
    notifyListeners();
  }

  // 完成所有游戏
  Future<void> completeGame() async {
    print('[GameProvider] 标记游戏完成');
    _isGameCompleted = true;
    _currentLevel = 4;
    
    // 保存到本地
    await _prefs.setBool('isGameCompleted', true);
    await _prefs.setInt('currentLevel', 4);
    
    // 保存到服务器
    if (_userId != null) {
      try {
        await _apiService.completeGame(_userId!);
        print('[GameProvider] 游戏完成状态已同步到服务器');
      } catch (e) {
        print('[GameProvider] 同步到服务器失败: $e');
      }
    }
    
    notifyListeners();
  }

  // 重置游戏进度（用于测试）
  Future<void> resetGame() async {
    _isGameCompleted = false;
    _currentLevel = 0;
    await _prefs.setBool('isGameCompleted', false);
    await _prefs.setInt('currentLevel', 0);
    notifyListeners();
  }
}
