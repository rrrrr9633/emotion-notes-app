import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import 'auth/login_screen.dart';
import 'auth/partner_bind_screen.dart';
import 'welcome_animation_screen.dart';
import 'game/game_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    print('=== 检查登录状态 ===');
    print('- isLoggedIn: ${authProvider.isLoggedIn}');
    print('- isPartnerBound: ${authProvider.isPartnerBound}');
    print('- userId: ${authProvider.userId}');

    // 如果已登录，设置游戏进度的userId并从服务器加载
    if (authProvider.isLoggedIn && authProvider.userId != null) {
      print('正在加载游戏进度...');
      await gameProvider.setUserId(authProvider.userId!);
      print('- isGameCompleted: ${gameProvider.isGameCompleted}');
      print('- currentLevel: ${gameProvider.currentLevel}');
    }

    // 检查登录状态
    if (!authProvider.isLoggedIn) {
      // 未登录 -> 跳转到登录页面
      print('跳转到登录页面');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (!authProvider.isPartnerBound) {
      // 已登录但未绑定情侣 -> 跳转到绑定页面
      print('跳转到绑定页面');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PartnerBindScreen()),
      );
    } else {
      // 已登录且已绑定 -> 显示欢迎动画
      print('跳转到欢迎动画');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeAnimationScreen()),
      );
    }
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TODO: 这里可以放置你的可爱风卡通图片或3D模型
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 80,
                  color: Color(0xFFFF6B9D),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                '情绪便利贴',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B9D),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '记录我们的小情绪',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.pink.shade300,
                ),
              ),
              const SizedBox(height: 50),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
