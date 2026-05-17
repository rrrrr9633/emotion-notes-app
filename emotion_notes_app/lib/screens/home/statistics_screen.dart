import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _statistics;
  Map<String, dynamic>? _achievement;
  bool _isLoading = true;
  int _selectedDays = 7;

  final Map<String, Color> _emotionColors = {
    '生气': const Color(0xFFFF6B6B),
    '难过': const Color(0xFF4ECDC4),
    '委屈': const Color(0xFFFFE66D),
    '失望': const Color(0xFF95E1D3),
    '焦虑': const Color(0xFFFFA07A),
  };

  final Map<String, String> _petStageEmojis = {
    'egg': '🥚',
    'baby': '🐣',
    'child': '🐥',
    'teen': '🐤',
    'adult': '🐓',
  };

  final Map<String, String> _petStageNames = {
    'egg': '蛋',
    'baby': '幼年',
    'child': '儿童',
    'teen': '少年',
    'adult': '成年',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        throw Exception('用户未登录');
      }

      // 并行加载统计和成就数据
      final results = await Future.wait([
        _apiService.getStatistics(userId: userId, days: _selectedDays),
        _apiService.getAchievement(userId),
      ]);

      if (mounted) {
        setState(() {
          _statistics = results[0]['success'] == true
              ? results[0]['statistics']
              : null;
          _achievement = results[1]['success'] == true
              ? results[1]['achievement']
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('加载统计数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '情绪统计',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间范围选择
                  _buildTimeRangeSelector(),

                  const SizedBox(height: 24),

                  // 虚拟宠物成就
                  if (_achievement != null) _buildAchievementCard(),

                  const SizedBox(height: 20),

                  // 统计概览
                  if (_statistics != null) _buildStatisticsOverview(),

                  const SizedBox(height: 20),

                  // 情绪分布
                  if (_statistics != null) _buildEmotionDistribution(),

                  const SizedBox(height: 20),

                  // 提示文字
                  _buildTips(),
                ],
              ),
            ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTimeRangeButton('7天', 7),
          _buildTimeRangeButton('30天', 30),
          _buildTimeRangeButton('90天', 90),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, int days) {
    final isSelected = _selectedDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDays = days;
          });
          _loadData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard() {
    final totalResolved = _achievement!['total_resolved'] ?? 0;
    final currentLevel = _achievement!['current_level'] ?? 1;
    final petStage = _achievement!['pet_stage'] ?? 'egg';
    final progress = totalResolved % 10;
    
    // 计算当前周期和重生次数
    final rebirthCount = totalResolved ~/ 1000;
    final cycleProgress = totalResolved % 1000;
    final isMaxLevel = currentLevel == 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B9D), Color(0xFFFFC371)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B9D).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '你的虚拟宠物',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (rebirthCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '⭐ 重生 $rebirthCount 次',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _petStageEmojis[petStage] ?? '🥚',
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 12),
          Text(
            _petStageNames[petStage] ?? '蛋',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Lv.$currentLevel',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              if (isMaxLevel) ...[
                const SizedBox(width: 8),
                const Text(
                  '(满级)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '总消气次数',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$totalResolved 次',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isMaxLevel ? '距离重生' : '距离下一级',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${10 - progress} 次',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (isMaxLevel) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '💫 达到100级后将重生为蛋，开始新的旅程',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress / 10,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsOverview() {
    final totalNotes = _statistics!['total_notes'] ?? 0;
    final resolvedNotes = _statistics!['resolved_notes'] ?? 0;
    final resolveRate = _statistics!['resolve_rate'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '统计概览',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '便利贴总数',
                  '$totalNotes',
                  Icons.note_outlined,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  '已消气',
                  '$resolvedNotes',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatItem(
            '消气率',
            '${resolveRate.toStringAsFixed(1)}%',
            Icons.trending_up,
            const Color(0xFFFF6B9D),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionDistribution() {
    final emotionCounts =
        _statistics!['emotion_counts'] as Map<String, dynamic>? ?? {};

    if (emotionCounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            '暂无情绪数据',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final total = emotionCounts.values.fold<int>(0, (sum, count) => sum + (count as int));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '情绪分布',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          ...emotionCounts.entries.map((entry) {
            final emotion = entry.key;
            final count = entry.value as int;
            final percentage = (count / total * 100).toStringAsFixed(1);
            final color = _emotionColors[emotion] ?? Colors.grey;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        emotion,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                      Text(
                        '$count 次 ($percentage%)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: count / total,
                      minHeight: 8,
                      backgroundColor: color.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B9D).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Color(0xFFFF6B9D),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '温馨提示',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF6B9D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '这些数据是为了帮助你觉察情绪模式，而不是用来指责。每一次情绪都值得被看见和理解。💕',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
