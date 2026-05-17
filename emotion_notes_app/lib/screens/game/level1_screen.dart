import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/music_player.dart';
import '../../providers/auth_provider.dart';
import 'level2_screen.dart';

class Level1Screen extends StatefulWidget {
  const Level1Screen({super.key});

  @override
  State<Level1Screen> createState() => _Level1ScreenState();
}

class _Level1ScreenState extends State<Level1Screen>
    with TickerProviderStateMixin {
  int _currentQuestion = 0;
  final _smellController = TextEditingController();
  final _firstWordsController = TextEditingController();
  final _metaphorController = TextEditingController();
  
  String? _selectedSmell;
  String? _selectedMetaphor;
  
  late AnimationController _snowController;
  late AnimationController _fadeController;
  
  final ApiService _apiService = ApiService();
  bool _isLoadingBlessing = false;
  
  final List<String> _smellOptions = ['雨后', '拿铁', '海风', '图书馆旧书'];
  final List<String> _metaphorOptions = [
    '两辆错轨的列车突然并线',
    '便利店最后一支融化的冰淇淋',
  ];

  @override
  void initState() {
    super.initState();
    _snowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _snowController.dispose();
    _fadeController.dispose();
    _smellController.dispose();
    _firstWordsController.dispose();
    _metaphorController.dispose();
    super.dispose();
  }

  void _nextQuestion() {
    if (_currentQuestion < 2) {
      setState(() {
        _currentQuestion++;
        _fadeController.reset();
        _fadeController.forward();
      });
    } else {
      // 完成第一关，获取AI祝福
      _fetchAIBlessing();
    }
  }

  Future<void> _fetchAIBlessing() async {
    setState(() {
      _isLoadingBlessing = true;
    });

    try {
      final result = await _apiService.getLevel1Blessing(
        smell: _smellController.text,
        firstWords: _firstWordsController.text,
        metaphor: _metaphorController.text,
      );

      if (mounted) {
        setState(() {
          _isLoadingBlessing = false;
        });

        if (result['success'] == true) {
          await _showBlessing(
            result['blessing'] ?? '愿你们的爱情像初雪一样纯净，像星光一样永恒。💕',
            result['ai_name'] ?? 'AURA',
          );
        } else {
          // 如果API调用失败，显示默认祝福
          await _showBlessing(
            '亲爱的，你们的相遇充满了美好与浪漫。愿你们的爱情像初雪一样纯净，像星光一样永恒。每一个瞬间都值得珍藏，每一份感动都值得铭记。💕✨',
            'AURA',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBlessing = false;
        });
        // 出错时显示默认祝福
        await _showBlessing(
          '亲爱的，你们的相遇充满了美好与浪漫。愿你们的爱情像初雪一样纯净，像星光一样永恒。每一个瞬间都值得珍藏，每一份感动都值得铭记。💕✨',
          'AURA',
        );
      }
    }
  }

  Future<void> _saveLevel1Data(String blessing) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      
      if (userId == null) return;

      await _apiService.saveLevel1Data(
        userId: userId,
        smell: _smellController.text,
        firstWords: _firstWordsController.text,
        metaphor: _metaphorController.text,
        blessing: blessing,
      );
      
      print('第一关数据已保存');
    } catch (e) {
      print('保存第一关数据失败: $e');
    }
  }

  Future<void> _showBlessing(String blessing, String aiName) async {
    // 异步保存第一关数据到后端（不阻塞UI）
    _saveLevel1Data(blessing);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI头像
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFFC371)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B9D).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '💕',
                  style: TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$aiName的祝福',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B9D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Affectionate Understanding & Romantic Assistant',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                blessing,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.8,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 跳转到第二关
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const Level2Screen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B9D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '下一关 ✨',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 雪花背景
          ...List.generate(15, (index) => _buildSnowflake(index)),
          
          // 主要内容
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80), // 为音乐播放器留空间
                
                // 顶部进度
                _buildProgress(),
                
                // 问题内容
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: _buildQuestionContent(),
                  ),
                ),
                
                // 底部按钮
                _buildBottomButton(),
              ],
            ),
          ),
          
          // 音乐播放器
          MusicPlayer(
            themeColor: Colors.black,
            level: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildSnowflake(int index) {
    final random = math.Random(index);
    final startX = random.nextDouble();
    final duration = 3 + random.nextDouble() * 2;
    final size = 4 + random.nextDouble() * 4;
    
    return AnimatedBuilder(
      animation: _snowController,
      builder: (context, child) {
        final progress = (_snowController.value + index * 0.1) % 1.0;
        return Positioned(
          left: MediaQuery.of(context).size.width * startX,
          top: MediaQuery.of(context).size.height * progress,
          child: Opacity(
            opacity: (1 - progress) * 0.6,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            '第一关：相遇',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '像初雪一样干净、轻盈的回忆',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index <= _currentQuestion
                        ? Colors.black
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent() {
    switch (_currentQuestion) {
      case 0:
        return _buildQuestion1();
      case 1:
        return _buildQuestion2();
      case 2:
        return _buildQuestion3();
      default:
        return Container();
    }
  }

  Widget _buildQuestion1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '你们第一次看见彼此的那一天，\n空气里有什么味道？',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '可以是咖啡香、雨水味、消毒水，\n或者"我只是心跳加速，闻不到别的"',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _smellOptions.map((smell) {
                    final isSelected = _selectedSmell == smell;
                    return ChoiceChip(
                      label: Text(smell),
                      selected: isSelected,
                      selectedColor: Colors.black,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedSmell = selected ? smell : null;
                          if (selected) {
                            _smellController.text = smell;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _smellController,
                  decoration: InputDecoration(
                    hintText: '或者自己写...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setState(() => _selectedSmell = null);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '是谁先开口说了第一句话？\n那句话你还记得吗？',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '如果记不清了，可以写\n"我不记得内容，只记得声音很好听"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _firstWordsController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '写下那句话...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '如果用一个比喻来形容你们的相遇，\n你会选什么？',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ..._metaphorOptions.map((metaphor) {
              final isSelected = _selectedMetaphor == metaphor;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMetaphor = metaphor;
                      _metaphorController.text = metaphor;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      metaphor,
                      style: TextStyle(
                        fontSize: 16,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            TextField(
              controller: _metaphorController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '或者自己写一个比喻...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() => _selectedMetaphor = null);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    bool canProceed = false;
    
    switch (_currentQuestion) {
      case 0:
        canProceed = _smellController.text.isNotEmpty;
        break;
      case 1:
        canProceed = _firstWordsController.text.isNotEmpty;
        break;
      case 2:
        canProceed = _metaphorController.text.isNotEmpty;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: (canProceed && !_isLoadingBlessing) ? _nextQuestion : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoadingBlessing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _currentQuestion < 2 ? '下一题' : '完成',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
