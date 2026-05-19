import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/music_service.dart';
import 'game/game_screen.dart';
import 'home/home_screen.dart';

class WelcomeAnimationScreen extends StatefulWidget {
  const WelcomeAnimationScreen({super.key});

  @override
  State<WelcomeAnimationScreen> createState() => _WelcomeAnimationScreenState();
}

class _WelcomeAnimationScreenState extends State<WelcomeAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    
    _checkGameStatus();
  }

  Future<void> _checkGameStatus() async {
    // 等待动画播放
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    print('检查游戏状态:');
    print('- isGameCompleted: ${gameProvider.isGameCompleted}');
    print('- currentLevel: ${gameProvider.currentLevel}');
    
    if (gameProvider.isGameCompleted) {
      // 已完成闯关 -> 直接进入主界面
      print('游戏已完成，跳转到主界面');
      await MusicService().stop();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // 未完成闯关 -> 进入游戏警告页面
      print('游戏未完成，跳转到游戏警告页面');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
            colors: [
              Color(0xFFFFE5EC),
              Color(0xFFFFF0F5),
              Color(0xFFFFE5F0),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // TODO: 这里可以放置欢迎动画或可爱风图片
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 100,
                          color: Color(0xFFFF6B9D),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        '欢迎来到',
                        style: TextStyle(
                          fontSize: 24,
                          color: Color(0xFFFF6B9D),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '我们的情绪小屋',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B9D),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
