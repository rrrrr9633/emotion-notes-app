import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../widgets/music_player.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'level4_screen.dart';

class Level3Screen extends StatefulWidget {
  const Level3Screen({super.key});

  @override
  State<Level3Screen> createState() => _Level3ScreenState();
}

class _Level3ScreenState extends State<Level3Screen>
    with TickerProviderStateMixin {
  int _currentNode = -1; // -1表示未开始，0/1/2表示三个节点
  
  final _year1Controller = TextEditingController();
  final _year3Controller = TextEditingController();
  final _year10Controller = TextEditingController();
  
  late AnimationController _timelineController;
  late AnimationController _nodeController;
  late Animation<double> _timelineAnimation;
  late Animation<double> _nodeAnimation;
  
  bool _isLoadingBlessing = false;
  final ApiService _apiService = ApiService();
  String _blessing = '';
  
  final List<Map<String, dynamic>> _nodes = [
    {
      'year': '1年后',
      'question': '你们最想一起改掉的一个小毛病',
      'hint': '例如："不再为谁洗碗生气"',
      'icon': '🌱',
    },
    {
      'year': '3年后',
      'question': '你们会在哪个城市或场景里吃一顿最普通的早餐？',
      'hint': '例如："还是这个出租屋，但窗台多了一盆薄荷"',
      'icon': '🏠',
    },
    {
      'year': '10年后',
      'question': '如果你们有了孩子/宠物/一墙爬山虎，你希望那天的午后你们在做什么？',
      'hint': '自由写...',
      'icon': '🌳',
    },
  ];

  @override
  void initState() {
    super.initState();
    
    _timelineController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _timelineAnimation = CurvedAnimation(
      parent: _timelineController,
      curve: Curves.easeInOut,
    );
    
    _nodeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _nodeAnimation = CurvedAnimation(
      parent: _nodeController,
      curve: Curves.elasticOut,
    );
    
    // 启动时间线动画
    Future.delayed(const Duration(milliseconds: 500), () {
      _timelineController.forward();
    });
  }

  @override
  void dispose() {
    _timelineController.dispose();
    _nodeController.dispose();
    _year1Controller.dispose();
    _year3Controller.dispose();
    _year10Controller.dispose();
    super.dispose();
  }

  void _selectNode(int index) {
    if (_currentNode == index) return;
    
    setState(() {
      _currentNode = index;
    });
    
    _nodeController.reset();
    _nodeController.forward();
  }

  TextEditingController _getCurrentController() {
    switch (_currentNode) {
      case 0:
        return _year1Controller;
      case 1:
        return _year3Controller;
      case 2:
        return _year10Controller;
      default:
        return TextEditingController();
    }
  }

  bool _canComplete() {
    return _year1Controller.text.isNotEmpty &&
        _year3Controller.text.isNotEmpty &&
        _year10Controller.text.isNotEmpty;
  }

  Future<void> _completeLevel() async {
    setState(() {
      _isLoadingBlessing = true;
    });

    try {
      // 调用API生成祝福
      final result = await _apiService.getLevel3Blessing(
        node1: _year1Controller.text,
        node2: _year3Controller.text,
        node3: _year10Controller.text,
      );
      
      if (mounted) {
        setState(() {
          _isLoadingBlessing = false;
        });
        
        if (result['success'] == true) {
          _blessing = result['blessing'] ?? '未来不需要很宏大，有具体的画面就够了。你看，你已经画好了三张草图。';
        } else {
          _blessing = '未来不需要很宏大，有具体的画面就够了。你看，你已经画好了三张草图。';
        }
        
        await _showBlessingDialog();
      }
    } catch (e) {
      print('完成关卡失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingBlessing = false;
          _blessing = '未来不需要很宏大，有具体的画面就够了。你看，你已经画好了三张草图。';
        });
        await _showBlessingDialog();
      }
    }
  }

  Future<void> _saveLevel3Data() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      
      if (userId == null) return;

      await _apiService.saveLevel3Data(
        userId: userId,
        habit: _year1Controller.text,
        moment: _year3Controller.text,
        futurePlan: _year10Controller.text,
        blessing: _blessing,
      );
      
      print('第三关数据已保存');
    } catch (e) {
      print('保存第三关数据失败: $e');
    }
  }

  Future<void> _showBlessingDialog() async {
    // 异步保存第三关数据到后端（不阻塞UI）
    _saveLevel3Data();
    
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
                    colors: [Color(0xFFFFF8DC), Color(0xFFFFD700)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🗺️',
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
                  color: Color(0xFFDAA520),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnswerItem('1年后', _year1Controller.text, '🌱'),
                    const SizedBox(height: 12),
                    _buildAnswerItem('3年后', _year3Controller.text, '🏠'),
                    const SizedBox(height: 12),
                    _buildAnswerItem('10年后', _year10Controller.text, '🌳'),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      '未来不需要很宏大，有具体的画面就够了。你看，你已经画好了三张草图。',
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
                  onPressed: () {
                    Navigator.of(context).pop();
                    // 跳转到第四关
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const Level4Screen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDAA520),
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
      ),
    );
  }

  Widget _buildAnswerItem(String year, String answer, String icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                year,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                answer,
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
      backgroundColor: const Color(0xFFFFFAF0),
      body: Stack(
        children: [
          // 主要内容
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80), // 为音乐播放器留空间
                
                // 顶部标题
                _buildHeader(),
                
                // 内容区域
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // 时间线
                        _buildTimeline(),
                        
                        const SizedBox(height: 40),
                        
                        // 问题卡片
                        if (_currentNode >= 0) _buildQuestionCard(),
                        
                        const SizedBox(height: 100), // 为底部按钮留空间
                      ],
                    ),
                  ),
                ),
                
                // 底部按钮
                if (_canComplete()) _buildBottomButton(),
              ],
            ),
          ),
          
          // 音乐播放器
          MusicPlayer(
            themeColor: const Color(0xFFDAA520),
            level: 3,
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
            '第三关：期许',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDAA520),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '给未来画一张地图',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return AnimatedBuilder(
      animation: _timelineAnimation,
      builder: (context, child) {
        return SizedBox(
          height: 400,
          child: CustomPaint(
            size: const Size(double.infinity, 400),
            painter: TimelinePainter(
              progress: _timelineAnimation.value,
              selectedNode: _currentNode,
            ),
            child: Stack(
              children: [
                // 三个节点
                for (int i = 0; i < 3; i++)
                  _buildNode(i),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNode(int index) {
    final positions = [
      const Offset(0.2, 0.2),
      const Offset(0.5, 0.5),
      const Offset(0.8, 0.8),
    ];
    
    final isSelected = _currentNode == index;
    final isCompleted = _getCurrentControllerByIndex(index).text.isNotEmpty;
    
    return Positioned(
      left: MediaQuery.of(context).size.width * positions[index].dx - 40,
      top: 400 * positions[index].dy - 40,
      child: GestureDetector(
        onTap: () => _selectNode(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFFDAA520)
                : isSelected
                    ? Colors.white
                    : const Color(0xFFFFF8DC),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFDAA520),
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDAA520).withOpacity(0.3),
                blurRadius: isSelected ? 20 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _nodes[index]['icon'],
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                _nodes[index]['year'],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? Colors.white : const Color(0xFFDAA520),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextEditingController _getCurrentControllerByIndex(int index) {
    switch (index) {
      case 0:
        return _year1Controller;
      case 1:
        return _year3Controller;
      case 2:
        return _year10Controller;
      default:
        return TextEditingController();
    }
  }

  Widget _buildQuestionCard() {
    final node = _nodes[_currentNode];
    final controller = _getCurrentController();
    
    return ScaleTransition(
      scale: _nodeAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            Row(
              children: [
                Text(
                  node['icon'],
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    node['year'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDAA520),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              node['question'],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              node['hint'],
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '写下你的期许...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFDAA520),
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
          onPressed: _isLoadingBlessing ? null : _completeLevel,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDAA520),
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
              : const Text(
                  '完成',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}

// 时间线绘制器
class TimelinePainter extends CustomPainter {
  final double progress;
  final int selectedNode;

  TimelinePainter({
    required this.progress,
    required this.selectedNode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDAA520).withOpacity(0.3)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // 绘制弯曲的时间线
    final startX = size.width * 0.2;
    final startY = size.height * 0.2;
    
    final midX = size.width * 0.5;
    final midY = size.height * 0.5;
    
    final endX = size.width * 0.8;
    final endY = size.height * 0.8;
    
    path.moveTo(startX, startY);
    
    // 使用二次贝塞尔曲线创建弯曲效果
    path.quadraticBezierTo(
      midX - 50,
      midY - 30,
      midX,
      midY,
    );
    
    path.quadraticBezierTo(
      midX + 50,
      midY + 30,
      endX,
      endY,
    );
    
    // 绘制路径
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final extractPath = metric.extractPath(
        0,
        metric.length * progress,
      );
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedNode != selectedNode;
  }
}
