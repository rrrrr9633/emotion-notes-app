import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _memories;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        throw Exception('用户未登录');
      }

      final result = await _apiService.getMemories(userId);

      if (result['success'] == true && mounted) {
        setState(() {
          _memories = result['memories'];
          _isLoading = false;
        });
      } else {
        throw Exception(result['message'] ?? '加载失败');
      }
    } catch (e) {
      print('加载回忆失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B9D),
        title: const Text(
          '我们的回忆',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _memories == null || _memories!.isEmpty
              ? const Center(child: Text('还没有回忆'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLevelCard(
                        level: 1,
                        title: '第一关：相遇',
                        emoji: '💕',
                        color: const Color(0xFFFFB6C1),
                        data: _memories!['level1'],
                      ),
                      const SizedBox(height: 16),
                      _buildLevelCard(
                        level: 2,
                        title: '第二关：初见',
                        emoji: '🌸',
                        color: const Color(0xFFFFDAB9),
                        data: _memories!['level2'],
                      ),
                      const SizedBox(height: 16),
                      _buildLevelCard(
                        level: 3,
                        title: '第三关：期许',
                        emoji: '✨',
                        color: const Color(0xFFE6E6FA),
                        data: _memories!['level3'],
                      ),
                      const SizedBox(height: 16),
                      _buildLevelCard(
                        level: 4,
                        title: '第四关：相爱总会有阴天',
                        emoji: '🌈',
                        color: const Color(0xFFB0E0E6),
                        data: _memories!['level4'],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLevelCard({
    required int level,
    required String title,
    required String emoji,
    required Color color,
    required Map<String, dynamic>? data,
  }) {
    if (data == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '还未完成 $title',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // 根据关卡显示不同内容
          if (level == 1) ...[
            _buildDataItem('Ta的味道', data['smell']),
            _buildDataItem('第一句话', data['first_words']),
            _buildDataItem('Ta像什么', data['metaphor']),
          ] else if (level == 2) ...[
            _buildDataItem('喜欢的颜色', data['color']),
            _buildDataItem('难忘的对话', data['dialogue']),
            _buildDataItem('专属歌曲', data['song']),
            if (data['photo_url'] != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  data['photo_url'],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ] else if (level == 3) ...[
            _buildDataItem('Ta的习惯', data['habit']),
            _buildDataItem('难忘时刻', data['moment']),
            _buildDataItem('未来计划', data['future_plan']),
          ] else if (level == 4) ...[
            _buildDataItem('让Ta开心的事', data['action']),
            _buildDataItem('温柔的话', data['phrase']),
            _buildDataItem('和好仪式', data['ritual']),
            _buildDataItem('原谅的话', data['forgive_message']),
          ],
          
          // AI祝福
          if (data['blessing'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '💕',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AURA的祝福',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['blessing'],
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataItem(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
