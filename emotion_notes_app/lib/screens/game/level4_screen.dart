import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../widgets/music_player.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';

class Level4Screen extends StatefulWidget {
  const Level4Screen({super.key});

  @override
  State<Level4Screen> createState() => _Level4ScreenState();
}

class _Level4ScreenState extends State<Level4Screen>
    with TickerProviderStateMixin {
  int _currentQuestion = 0;
  
  String? _selectedAction;
  String? _selectedPhrase;
  String? _selectedRitual;
  
  final _customActionController = TextEditingController();
  final _customPhraseController = TextEditingController();
  final _customRitualController = TextEditingController();
  final _forgiveMessageController = TextEditingController();
  
  late AnimationController _waveController;
  late AnimationController _fadeController;
  
  bool _isLoadingBlessing = false;
  final ApiService _apiService = ApiService();
  String _blessing = '';
  
  // 问题1的选项
  final List<String> _actionOptions = [
    '轻轻捏一下我的小拇指',
    '突然模仿那天我出糗的表情',
    '把泡好的茶推到我面前不说话',
  ];
  
  // 问题2的选项
  final List<String> _phraseOptions = [
    '我知道你不是故意凶我',
    '我们点那家炸鸡吧',
    '先休战，我想抱你',
  ];
  
  // 问题3的选项
  final List<String> _ritualOptions = [
    '一起给家里的植物浇水',
    '划拳决定谁先笑',
    '互相往对方脸上贴一张贴纸',
  ];

  @override
  void initState() {
    super.initState();
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 8),
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
    _waveController.dispose();
    _fadeController.dispose();
    _customActionController.dispose();
    _customPhraseController.dispose();
    _customRitualController.dispose();
    _forgiveMessageController.dispose();
    super.dispose();
  }

  void _nextQuestion() {
    if (_currentQuestion < 3) {
      setState(() {
        _currentQuestion++;
        _fadeController.reset();
        _fadeController.forward();
      });
    } else {
      _completeLevel();
    }
  }

  String _getCurrentAnswer() {
    switch (_currentQuestion) {
      case 0:
        return _customActionController.text.isNotEmpty
            ? _customActionController.text
            : _selectedAction ?? '';
      case 1:
        return _customPhraseController.text.isNotEmpty
            ? _customPhraseController.text
            : _selectedPhrase ?? '';
      case 2:
        return _customRitualController.text.isNotEmpty
            ? _customRitualController.text
            : _selectedRitual ?? '';
      case 3:
        return _forgiveMessageController.text;
      default:
        return '';
    }
  }

  bool _canProceed() {
    return _getCurrentAnswer().isNotEmpty;
  }

  Future<void> _completeLevel() async {
    setState(() {
      _isLoadingBlessing = true;
    });

    try {
      final action = _customActionController.text.isNotEmpty
          ? _customActionController.text
          : _selectedAction ?? '';
      final phrase = _customPhraseController.text.isNotEmpty
          ? _customPhraseController.text
          : _selectedPhrase ?? '';
      final ritual = _customRitualController.text.isNotEmpty
          ? _customRitualController.text
          : _selectedRitual ?? '';
      final forgiveMessage = _forgiveMessageController.text;

      print('[Level4] 开始生成祝福...');
      
      // 先设置默认祝福，避免等待
      _blessing = '蓝色是深海的颜色——表面有风浪，但深处始终安静。你们提前写下的这些，就是彼此的锚。';
      
      // 尝试调用API生成祝福（带超时）
      try {
        final result = await _apiService.getLevel4Blessing(
          action: action,
          phrase: phrase,
          ritual: ritual,
          forgiveMessage: forgiveMessage,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('[Level4] API调用超时，使用默认祝福');
            return {'success': false, 'message': '超时'};
          },
        );
        
        if (result['success'] == true && result['blessing'] != null) {
          _blessing = result['blessing'];
          print('[Level4] 成功获取AI祝福');
        } else {
          print('[Level4] API返回失败，使用默认祝福');
        }
      } catch (e) {
        print('[Level4] 获取祝福异常: $e，使用默认祝福');
      }
      
      if (mounted) {
        setState(() {
          _isLoadingBlessing = false;
        });
        print('[Level4] 显示祝福对话框');
        await _showBlessingDialog();
      }
    } catch (e) {
      print('[Level4] 完成关卡失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingBlessing = false;
          _blessing = '蓝色是深海的颜色——表面有风浪，但深处始终安静。你们提前写下的这些，就是彼此的锚。';
        });
        await _showBlessingDialog();
      }
    }
  }

  Future<void> _saveLevel4Data(String action, String phrase, String ritual, String forgiveMessage) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      
      if (userId == null) return;

      print('[Level4] 开始保存第四关数据...');
      final result = await _apiService.saveLevel4Data(
        userId: userId,
        action: action,
        phrase: phrase,
        ritual: ritual,
        forgiveMessage: forgiveMessage,
        blessing: _blessing,
      );
      
      if (result['success'] == true) {
        print('[Level4] 第四关数据保存成功');
      } else {
        print('[Level4] 第四关数据保存失败: ${result['message']}');
      }
    } catch (e) {
      print('[Level4] 保存第四关数据异常: $e');
    }
  }

  Future<void> _showBlessingDialog() async {
    final action = _customActionController.text.isNotEmpty
        ? _customActionController.text
        : _selectedAction ?? '';
    final phrase = _customPhraseController.text.isNotEmpty
        ? _customPhraseController.text
        : _selectedPhrase ?? '';
    final ritual = _customRitualController.text.isNotEmpty
        ? _customRitualController.text
        : _selectedRitual ?? '';
    final forgiveMessage = _forgiveMessageController.text;
    
    // 先显示弹窗，不等待保存
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI头像
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '⚓',
                    style: TextStyle(fontSize: 40),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'AURA的祝福',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '你们的"吵架使用说明书"：',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildManualItem('1. 先做这件事', action, '🤝'),
                    const SizedBox(height: 10),
                    _buildManualItem('2. 说这句话', phrase, '💬'),
                    const SizedBox(height: 10),
                    _buildManualItem('3. 和好仪式', ritual, '🕊️'),
                    const SizedBox(height: 10),
                    _buildManualItem('4. 提前的原谅', forgiveMessage, '💙'),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      '蓝色是深海的颜色——表面有风浪，但深处始终安静。你们提前写下的这些，就是彼此的锚。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.8,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();

                    final gameProvider =
                        Provider.of<GameProvider>(context, listen: false);

                    // 先保存第四关数据，再标记完成并停止音乐
                    await _saveLevel4Data(
                      action,
                      phrase,
                      ritual,
                      forgiveMessage,
                    );
                    await gameProvider.completeGame();

                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/home',
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '完成所有关卡 ✨',
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
      ),
    );
  }

  Widget _buildManualItem(String title, String content, String icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 波纹背景
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height),
                painter: WavePainter(progress: _waveController.value),
              );
            },
          ),
          
          // 主要内容
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80), // 为音乐播放器留空间
                
                // 顶部标题
                _buildHeader(),
                
                // 问题内容
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: _buildQuestionContent(),
                  ),
                ),
                
                // 底部按钮
                if (_canProceed()) _buildBottomButton(),
              ],
            ),
          ),
          
          // 音乐播放器
          MusicPlayer(
            themeColor: const Color(0xFF3B82F6),
            level: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            '第四关：相爱总会有阴天',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '提前写好的"吵架使用说明书"',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          // 进度指示器
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index <= _currentQuestion
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
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
      case 3:
        return _buildQuestion4();
      default:
        return Container();
    }
  }

  Widget _buildQuestion1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '问题 1',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '下一次你们因为很小的事吵架，你希望对方先做哪一件具体的事？',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '（不是"低头道歉"，而是可执行的动作）',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            ..._actionOptions.map((action) {
              final isSelected = _selectedAction == action;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedAction = action;
                      _customActionController.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      action,
                      style: TextStyle(
                        fontSize: 15,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            TextField(
              controller: _customActionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '或者自己写一个动作...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() => _selectedAction = null);
                } else {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '问题 2',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '哪一句话，只要你听到，情绪就会立刻软下来？',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '（哪怕当时还在生气）',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            ..._phraseOptions.map((phrase) {
              final isSelected = _selectedPhrase == phrase;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPhrase = phrase;
                      _customPhraseController.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      phrase,
                      style: TextStyle(
                        fontSize: 15,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            TextField(
              controller: _customPhraseController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '或者自己写一句话...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() => _selectedPhrase = null);
                } else {
                  setState(() {});
                }
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
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '问题 3',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '如果吵架后你们必须一起做一件很小的事情作为"和好仪式"，你希望是什么？',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ..._ritualOptions.map((ritual) {
              final isSelected = _selectedRitual == ritual;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedRitual = ritual;
                      _customRitualController.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      ritual,
                      style: TextStyle(
                        fontSize: 15,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            TextField(
              controller: _customRitualController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '或者自己写一个仪式...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() => _selectedRitual = null);
                } else {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '问题 4（最后一条）',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '给你们的未来某次吵架，提前原谅对方一次。',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '写一句你在这里想说的话，那时候由系统送给她/他。',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '例如："我知道那时候你也很委屈，我不需要你赢，我需要你回来。"',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _forgiveMessageController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '写下你想提前说的话...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 2,
                  ),
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

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoadingBlessing ? null : _nextQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
            disabledBackgroundColor: Colors.white.withOpacity(0.3),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                  ),
                )
              : Text(
                  _currentQuestion < 3 ? '下一题' : '完成',
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

// 波纹绘制器
class WavePainter extends CustomPainter {
  final double progress;

  WavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E40AF).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 绘制多层波纹
    for (int i = 0; i < 5; i++) {
      final path = Path();
      final amplitude = 20.0 + i * 5;
      final frequency = 0.02 - i * 0.002;
      final offset = progress * 2 * math.pi + i * math.pi / 3;

      path.moveTo(0, size.height / 2);

      for (double x = 0; x <= size.width; x += 5) {
        final y = size.height / 2 +
            amplitude * math.sin(frequency * x + offset);
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
