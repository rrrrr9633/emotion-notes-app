import 'package:flutter/material.dart';
import '../services/music_service.dart';

class MusicPlayer extends StatefulWidget {
  final Color themeColor;
  final int level;

  const MusicPlayer({
    super.key,
    required this.themeColor,
    required this.level,
  });

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  
  final MusicService _musicService = MusicService();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    // 初始化并播放音乐（只在第一次初始化时播放）
    _initMusic();
  }

  Future<void> _initMusic() async {
    await _musicService.initialize();
    
    // 只在第一次进入游戏时自动播放
    // 如果用户已经暂停过，就不要自动播放
    if (!_musicService.hasEverPlayed) {
      // 第一次进入，自动播放
      await _musicService.play();
    }
    // 如果已经播放过，保持用户的选择（播放或暂停）
    
    // 定期更新UI
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
        _startPeriodicUpdate();
      }
    });
  }

  @override
  void dispose() {
    _expandController.dispose();
    // 不要 dispose musicService，因为它是全局单例
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Column(
          children: [
            // 收起状态的小条
            GestureDetector(
              onTap: _toggleExpand,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.themeColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.themeColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _musicService.isPlaying ? Icons.music_note : Icons.music_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getLevelMusicName(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            
            // 展开状态的播放器
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.themeColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.themeColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 音乐名称
                    Text(
                      _getLevelMusicName(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 进度条
                    Column(
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: _musicService.position.inSeconds.toDouble(),
                            max: _musicService.duration.inSeconds.toDouble() > 0
                                ? _musicService.duration.inSeconds.toDouble()
                                : 1.0,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white.withOpacity(0.3),
                            onChanged: (value) async {
                              await _musicService.seek(Duration(seconds: value.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_musicService.position),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatDuration(_musicService.duration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 播放控制按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _musicService.rewind(),
                          icon: const Icon(Icons.replay_10, color: Colors.white),
                          iconSize: 32,
                        ),
                        const SizedBox(width: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => _musicService.togglePlayPause(),
                            icon: Icon(
                              _musicService.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: widget.themeColor,
                            ),
                            iconSize: 32,
                          ),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          onPressed: () => _musicService.forward(),
                          icon: const Icon(Icons.forward_10, color: Colors.white),
                          iconSize: 32,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLevelMusicName() {
    switch (widget.level) {
      case 1:
        return '第一关：相遇 ❄️';
      case 2:
        return '第二关：记忆 💕';
      case 3:
        return '第三关：冲突 ⚡';
      case 4:
        return '第四关：和解 🌟';
      default:
        return '背景音乐';
    }
  }
}
