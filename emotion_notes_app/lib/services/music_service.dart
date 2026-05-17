import 'package:audioplayers/audioplayers.dart';

/// 全局音乐服务 - 单例模式
/// 确保音乐在关卡切换时持续播放
class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _hasEverPlayed = false; // 新增：标记是否曾经播放过
  
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  // 音乐文件路径
  static const String _musicPath = 'music/me.mp3';

  // 获取播放状态
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;
  bool get hasEverPlayed => _hasEverPlayed;
  Duration get duration => _duration;
  Duration get position => _position;
  AudioPlayer get audioPlayer => _audioPlayer;

  /// 初始化音乐服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 监听音频时长
    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
    });

    // 监听播放进度
    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
    });

    // 监听播放完成（循环播放）
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _position = Duration.zero;
      // 自动重新播放
      play();
    });

    _isInitialized = true;
    print('[MusicService] 音乐服务已初始化');
  }

  /// 播放音乐
  Future<void> play() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (_isPlaying) {
        print('[MusicService] 音乐已在播放中');
        return;
      }

      print('[MusicService] 开始播放音乐: $_musicPath');
      await _audioPlayer.play(AssetSource(_musicPath));
      _isPlaying = true;
      _hasEverPlayed = true; // 标记已经播放过
      print('[MusicService] ✅ 音乐播放成功');
    } catch (e) {
      print('[MusicService] ❌ 播放失败: $e');
    }
  }

  /// 暂停音乐
  Future<void> pause() async {
    if (!_isPlaying) return;
    
    await _audioPlayer.pause();
    _isPlaying = false;
    print('[MusicService] 音乐已暂停');
  }

  /// 恢复播放
  Future<void> resume() async {
    if (_isPlaying) return;
    
    await _audioPlayer.resume();
    _isPlaying = true;
    print('[MusicService] 音乐已恢复');
  }

  /// 切换播放/暂停
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      if (_position.inSeconds > 0) {
        await resume();
      } else {
        await play();
      }
    }
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// 快进10秒
  Future<void> forward() async {
    final newPosition = _position + const Duration(seconds: 10);
    await seek(newPosition > _duration ? _duration : newPosition);
  }

  /// 快退10秒
  Future<void> rewind() async {
    final newPosition = _position - const Duration(seconds: 10);
    await seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  /// 停止音乐
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _position = Duration.zero;
    print('[MusicService] 音乐已停止');
  }

  /// 释放资源
  void dispose() {
    _audioPlayer.dispose();
    _isInitialized = false;
    print('[MusicService] 音乐服务已释放');
  }
}
