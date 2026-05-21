import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'note_detail_screen.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Map<String, List<Map<String, dynamic>>> _notesByMonth = {};
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadResolvedNotes();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadResolvedNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 获取所有已消气的便利贴
      final result = await _apiService.getNotesList(
        userId: userId,
        status: 'resolved', // 获取已消气的
      );

      if (result['success'] == true && mounted) {
        final notes = List<Map<String, dynamic>>.from(result['notes'] ?? []);
        
        // 按月份分组
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var note in notes) {
          final createdAt = DateTime.parse(note['created_at']);
          final monthKey = DateFormat('yyyy-MM').format(createdAt);
          if (!grouped.containsKey(monthKey)) {
            grouped[monthKey] = [];
          }
          grouped[monthKey]!.add(note);
        }

        setState(() {
          _notesByMonth = grouped;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('加载垃圾桶失败: $e');
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '便签垃圾桶',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notesByMonth.isEmpty
              ? _buildEmptyState()
              : _buildTrashList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '垃圾桶是空的',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已消气的便利贴会自动收入这里',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashList() {
    final sortedMonths = _notesByMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 最新月份在前

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final monthKey = sortedMonths[index];
        final notes = _notesByMonth[monthKey]!;
        return _buildMonthSection(monthKey, notes, index);
      },
    );
  }

  Widget _buildMonthSection(String monthKey, List<Map<String, dynamic>> notes, int index) {
    final date = DateTime.parse('$monthKey-01');
    final monthLabel = DateFormat('yyyy年MM月').format(date);
    
    // 添加延迟动画
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          index * 0.1,
          (index * 0.1) + 0.3,
          curve: Curves.easeOut,
        ),
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(animation),
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 月份标题 - 垃圾桶样式
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$monthLabel 便签垃圾桶',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${notes.length}张',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 便利贴列表
              ...notes.map((note) => _buildTrashNoteCard(note)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrashNoteCard(Map<String, dynamic> note) {
    final createdAt = DateTime.parse(note['created_at']);
    final emotionTag = note['emotion_tag'] ?? '情绪';

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoteDetailScreen(noteId: note['_id']),
          ),
        );
        if (result == true) {
          _loadResolvedNotes();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildEmotionTag(emotionTag),
                const Spacer(),
                Text(
                  DateFormat('MM-dd HH:mm').format(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '已消气',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              note['content'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionTag(String emotion) {
    final colors = {
      '生气': const Color(0xFFFF6B6B),
      '难过': const Color(0xFF4ECDC4),
      '委屈': const Color(0xFFFFE66D),
      '失望': const Color(0xFF95E1D3),
      '焦虑': const Color(0xFFFFA07A),
      '开心': const Color(0xFFFFD93D),
      '疲惫': const Color(0xFFB8B8D1),
      '平淡': const Color(0xFFE8E8E8),
      '幸福': const Color(0xFFFFB6C1),
    };

    final color = colors[emotion] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        emotion,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
