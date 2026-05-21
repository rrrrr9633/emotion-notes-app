import 'package:dio/dio.dart';

/// 将 Dio 异常转为可读提示（APK 与 Chrome 网络栈不同，需区分证书/超时等）
String networkErrorMessage(DioException e, {String? fallback}) {
  final data = e.response?.data;
  if (data is Map && data['message'] != null) {
    return data['message'].toString();
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return '连接超时，请确认手机网络能访问服务器';
    case DioExceptionType.connectionError:
      return '无法连接服务器：${e.message ?? "请检查网络与域名解析"}';
    case DioExceptionType.badCertificate:
      return 'HTTPS证书校验失败，请检查服务器SSL证书链是否配置完整';
    case DioExceptionType.badResponse:
      return fallback ?? '服务器错误 (${e.response?.statusCode})';
    default:
      return fallback ?? '网络错误: ${e.message}';
  }
}

class ApiService {
  // 生产环境服务器地址（通过nginx代理，不需要端口号）
  static const String baseUrl = 'https://sjzwudi.top/api';
  // 静态资源（头像、图片等）根地址
  static const String mediaOrigin = 'https://sjzwudi.top';

  /// 将后端返回的相对路径转为完整 URL，供 NetworkImage 使用
  static String? resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final path = url.startsWith('/') ? url : '/$url';
    return '$mediaOrigin$path';
  }
  
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60), // 延长到60秒,适配AI生成
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'EmotionNotesApp/1.0',
      },
    ),
  );

  ApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          print('[API] ${error.requestOptions.uri}');
          print('[API] 错误类型: ${error.type}, 信息: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  // 注册
  Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      print('正在注册: $username');
      print('API地址: $baseUrl/auth/register');
      
      final response = await _dio.post('/auth/register', data: {
        'username': username,
        'password': password,
      });
      
      print('注册响应: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('注册错误: ${e.type}');
      print('错误信息: ${e.message}');
      print('响应数据: ${e.response?.data}');
      
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    } catch (e) {
      print('未知错误: $e');
      return {
        'success': false,
        'message': '未知错误: $e',
      };
    }
  }

  // 登录
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 发送绑定请求
  Future<Map<String, dynamic>> sendBindRequest(String userId, String partnerUsername) async {
    try {
      final response = await _dio.post('/user/bind-request', data: {
        'userId': userId,
        'partnerUsername': partnerUsername,
      });
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 接受绑定请求
  Future<Map<String, dynamic>> acceptBindRequest(String requestId) async {
    try {
      final response = await _dio.post('/user/accept-bind', data: {
        'requestId': requestId,
      });
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取待处理的绑定请求
  Future<Map<String, dynamic>> getPendingBindRequests(String userId) async {
    try {
      final response = await _dio.get('/user/bind-requests/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取游戏进度
  Future<Map<String, dynamic>> getGameProgress(String userId) async {
    try {
      final response = await _dio.get('/game/progress/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 完成游戏
  Future<Map<String, dynamic>> completeGame(String userId) async {
    try {
      final response = await _dio.post('/game/complete/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 更新关卡
  Future<Map<String, dynamic>> updateLevel(String userId, int level) async {
    try {
      final response = await _dio.post('/game/update-level/$userId', 
        queryParameters: {'level': level}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  /// DeepSeek 生成较慢，祝福接口单独延长接收超时
  static final Options _aiBlessingOptions = Options(
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 30),
  );

  // 获取第一关AI祝福
  Future<Map<String, dynamic>> getLevel1Blessing({
    required String smell,
    required String firstWords,
    required String metaphor,
  }) async {
    try {
      final response = await _dio.post(
        '/game/level1/blessing',
        data: {
          'smell': smell,
          'first_words': firstWords,
          'metaphor': metaphor,
        },
        options: _aiBlessingOptions,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 上传第二关照片
  Future<Map<String, dynamic>> uploadLevel2Photo(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(filePath),
      });
      
      final response = await _dio.post('/game/level2/upload-photo', data: formData);
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取第二关AI祝福
  Future<Map<String, dynamic>> getLevel2Blessing({
    required String color,
    required String dialogue,
    required String song,
    required String photoUrl,
  }) async {
    try {
      final response = await _dio.post(
        '/game/level2/blessing',
        data: {
          'color': color,
          'dialogue': dialogue,
          'song': song,
          'photo_url': photoUrl,
        },
        options: _aiBlessingOptions,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取第三关AI祝福
  Future<Map<String, dynamic>> getLevel3Blessing({
    required String node1,
    required String node2,
    required String node3,
  }) async {
    try {
      final response = await _dio.post(
        '/game/level3/blessing',
        data: {
          'node1': node1,
          'node2': node2,
          'node3': node3,
        },
        options: _aiBlessingOptions,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取第四关AI祝福
  Future<Map<String, dynamic>> getLevel4Blessing({
    required String action,
    required String phrase,
    required String ritual,
    required String forgiveMessage,
  }) async {
    try {
      final response = await _dio.post(
        '/game/level4/blessing',
        data: {
          'action': action,
          'phrase': phrase,
          'ritual': ritual,
          'forgive_message': forgiveMessage,
        },
        options: _aiBlessingOptions,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // ========== 游戏数据永久保存API ==========
  
  // 保存第一关数据
  Future<Map<String, dynamic>> saveLevel1Data({
    required String userId,
    required String smell,
    required String firstWords,
    required String metaphor,
    required String blessing,
  }) async {
    try {
      final response = await _dio.post('/game/archive/level1', data: {
        'user_id': userId,
        'smell': smell,
        'first_words': firstWords,
        'metaphor': metaphor,
        'blessing': blessing,
      });
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 保存第二关数据
  Future<Map<String, dynamic>> saveLevel2Data({
    required String userId,
    required String color,
    required String dialogue,
    required String song,
    required String photoUrl,
    required String blessing,
  }) async {
    try {
      final response = await _dio.post('/game/archive/level2', data: {
        'user_id': userId,
        'color': color,
        'dialogue': dialogue,
        'song': song,
        'photo_url': photoUrl,
        'blessing': blessing,
      });
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 保存第三关数据
  Future<Map<String, dynamic>> saveLevel3Data({
    required String userId,
    required String habit,
    required String moment,
    required String futurePlan,
    required String blessing,
  }) async {
    try {
      final response = await _dio.post('/game/archive/level3', data: {
        'user_id': userId,
        'habit': habit,
        'moment': moment,
        'future_plan': futurePlan,
        'blessing': blessing,
      });
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 保存第四关数据
  Future<Map<String, dynamic>> saveLevel4Data({
    required String userId,
    required String action,
    required String phrase,
    required String ritual,
    required String forgiveMessage,
    required String blessing,
  }) async {
    try {
      final response = await _dio.post('/game/archive/level4', data: {
        'user_id': userId,
        'action': action,
        'phrase': phrase,
        'ritual': ritual,
        'forgive_message': forgiveMessage,
        'blessing': blessing,
      });
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取游戏存档
  Future<Map<String, dynamic>> getGameArchive(String userId) async {
    try {
      final response = await _dio.get('/game/archive/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // ========== 便利贴API ==========
  
  // 创建便利贴
  Future<Map<String, dynamic>> createNote({
    required String userId,
    required String content,
    required String emotionTag,
    String? title,
    String? audioUrl,
  }) async {
    try {
      final response = await _dio.post(
        '/notes/create',
        queryParameters: {'user_id': userId},
        data: {
          'content': content,
          'emotion_tag': emotionTag,
          if (title != null) 'title': title,
          if (audioUrl != null) 'audio_url': audioUrl,
        },
        options: _aiBlessingOptions,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 上传语音
  Future<Map<String, dynamic>> uploadAudio(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(filePath),
      });
      
      final response = await _dio.post('/notes/upload-audio', data: formData);
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取便利贴列表
  Future<Map<String, dynamic>> getNotesList({
    required String userId,
    int? year,
    int? month,
    String status = 'active',
  }) async {
    try {
      final response = await _dio.get('/notes/list/$userId',
        queryParameters: {
          if (year != null) 'year': year,
          if (month != null) 'month': month,
          'status': status,
        }
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取便利贴详情
  Future<Map<String, dynamic>> getNoteDetail({
    required String noteId,
    required String userId,
  }) async {
    try {
      final response = await _dio.get('/notes/detail/$noteId',
        queryParameters: {'user_id': userId}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 标记已消气
  Future<Map<String, dynamic>> markNoteResolved({
    required String noteId,
    required String userId,
  }) async {
    try {
      final response = await _dio.patch('/notes/resolve/$noteId',
        queryParameters: {'user_id': userId}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 归档便利贴
  Future<Map<String, dynamic>> archiveNote({
    required String noteId,
    required String userId,
  }) async {
    try {
      final response = await _dio.patch('/notes/archive/$noteId',
        queryParameters: {'user_id': userId}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 删除便利贴
  Future<Map<String, dynamic>> deleteNote({
    required String noteId,
    required String userId,
  }) async {
    try {
      final response = await _dio.delete('/notes/delete/$noteId',
        queryParameters: {'user_id': userId}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取统计数据
  Future<Map<String, dynamic>> getStatistics({
    required String userId,
    int days = 7,
  }) async {
    try {
      final response = await _dio.get('/notes/statistics/$userId',
        queryParameters: {'days': days}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取成就数据
  Future<Map<String, dynamic>> getAchievement(String userId) async {
    try {
      final response = await _dio.get('/notes/achievement/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // ========== 留言功能 ==========
  
  // 添加留言
  Future<Map<String, dynamic>> addComment({
    required String noteId,
    required String userId,
    required String content,
  }) async {
    try {
      final response = await _dio.post('/notes/comment/$noteId',
        queryParameters: {'user_id': userId},
        data: {'content': content}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取留言列表
  Future<Map<String, dynamic>> getComments({
    required String noteId,
    required String userId,
  }) async {
    try {
      final response = await _dio.get('/notes/comments/$noteId',
        queryParameters: {'user_id': userId}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // ========== 删除请求功能 ==========
  
  // 请求删除便利贴
  Future<Map<String, dynamic>> requestDeleteNote({
    required String noteId,
    required String userId,
  }) async {
    try {
      final response = await _dio.post('/notes/request-delete/$noteId',
        queryParameters: {'user_id': userId}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 同意删除便利贴
  Future<Map<String, dynamic>> approveDeleteNote({
    required String noteId,
    required String userId,
  }) async {
    try {
      final response = await _dio.post('/notes/approve-delete/$noteId',
        queryParameters: {'user_id': userId}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取删除请求列表
  Future<Map<String, dynamic>> getDeleteRequests(String userId) async {
    try {
      final response = await _dio.get('/notes/delete-requests/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // ========== 解绑功能 ==========
  
  // 请求解绑
  Future<Map<String, dynamic>> requestUnbind(String userId) async {
    try {
      final response = await _dio.post('/user/request-unbind/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 取消解绑
  Future<Map<String, dynamic>> cancelUnbind({
    required String requestId,
    required String userId,
  }) async {
    try {
      final response = await _dio.post('/user/cancel-unbind/$requestId',
        queryParameters: {'user_id': userId}
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取解绑状态
  Future<Map<String, dynamic>> getUnbindStatus(String userId) async {
    try {
      final response = await _dio.get('/user/unbind-status/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 获取回忆（对方的游戏数据）
  Future<Map<String, dynamic>> getMemories(String userId) async {
    try {
      final response = await _dio.get('/user/memories/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // ========== 用户资料API ==========
  
  // 获取用户资料
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _dio.get('/user/profile/$userId');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 更新用户资料
  Future<Map<String, dynamic>> updateUserProfile(
    String userId, {
    String? nickname,
    String? relationshipStartDate,
  }) async {
    try {
      final response = await _dio.patch('/user/profile/$userId', data: {
        if (nickname != null) 'nickname': nickname,
        if (relationshipStartDate != null) 'relationship_start_date': relationshipStartDate,
      });
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }

  // 上传头像
  Future<Map<String, dynamic>> uploadAvatar(
    String userId,
    String filePath, {
    String? filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          filePath,
          filename: filename ?? filePath.split(RegExp(r'[/\\]')).last,
        ),
      });

      final response = await _dio.post(
        '/user/upload-avatar/$userId',
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true && data['avatar_url'] != null) {
        data['avatar_url'] = resolveMediaUrl(data['avatar_url']);
      }
      return data;
    } on DioException catch (e) {
      print('[API] 上传头像失败: ${e.type} ${e.message}');
      return {
        'success': false,
        'message': networkErrorMessage(e),
      };
    }
  }
}
