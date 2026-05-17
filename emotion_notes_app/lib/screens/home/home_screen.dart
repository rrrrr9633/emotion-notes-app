import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import 'create_note_screen.dart';
import 'note_detail_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
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

      final result = await _apiService.getNotesList(
        userId: userId,
        year: _selectedDate.year,
        month: _selectedDate.month,
        status: 'active',
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _notes = List<Map<String, dynamic>>.from(result['notes'] ?? []);
          _isLoading = false;
        });
      } else {
        // API调用失败也要停止加载
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('加载便利贴失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildAppBar(),

            // 日期选择器
            _buildDateSelector(),

            // 便利贴列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notes.isEmpty
                      ? _buildEmptyState()
                      : _buildNotesList(),
            ),

            // 底部添加按钮
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: (value) async {
              if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('退出登录'),
                    content: const Text('确定要退出登录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确定',
                            style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.logout();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } else if (value == 'statistics') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StatisticsScreen(),
                  ),
                );
              } else if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.black, size: 20),
                    SizedBox(width: 12),
                    Text('个人资料'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'statistics',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, color: Colors.black, size: 20),
                    SizedBox(width: 12),
                    Text('情绪统计'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.black, size: 20),
                    SizedBox(width: 12),
                    Text('退出登录'),
                  ],
                ),
              ),
            ],
          ),
          const Text(
            '情绪便利贴',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: 1,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadNotes,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month - 1,
                );
              });
              _loadNotes();
            },
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
                _loadNotes();
              }
            },
            child: Text(
              DateFormat('yyyy年MM月').format(_selectedDate),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _selectedDate.month == DateTime.now().month &&
                    _selectedDate.year == DateTime.now().year
                ? null
                : () {
                    setState(() {
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        _selectedDate.month + 1,
                      );
                    });
                    _loadNotes();
                  },
          ),
        ],
      ),
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
            decoration: const BoxDecoration(
              color: Color(0xFFFFF5F7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.note_add_outlined,
              size: 60,
              color: Color(0xFFFF6B9D),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '这个月还没有便利贴',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '写下你的情绪，让AURA陪你聊聊',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return _buildNoteCard(note);
      },
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final isResolved = note['is_resolved'] == true;
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
          _loadNotes();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isResolved ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isResolved ? Colors.grey.shade300 : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: isResolved
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildEmotionTag(emotionTag, isResolved),
                const Spacer(),
                Text(
                  DateFormat('MM-dd HH:mm').format(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                if (isResolved) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '已消气',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              note['content'] ?? '',
              style: TextStyle(
                fontSize: 15,
                color: isResolved ? Colors.grey.shade600 : Colors.black87,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (note['ai_reply'] != null) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💕 ',
                    style: TextStyle(fontSize: 14),
                  ),
                  Expanded(
                    child: Text(
                      note['ai_reply'],
                      style: TextStyle(
                        fontSize: 13,
                        color: isResolved
                            ? Colors.grey.shade500
                            : const Color(0xFFFF6B9D),
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionTag(String emotion, bool isResolved) {
    final colors = {
      '生气': const Color(0xFFFF6B6B),
      '难过': const Color(0xFF4ECDC4),
      '委屈': const Color(0xFFFFE66D),
      '失望': const Color(0xFF95E1D3),
      '焦虑': const Color(0xFFFFA07A),
    };

    final color = colors[emotion] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isResolved ? Colors.grey.shade200 : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        emotion,
        style: TextStyle(
          fontSize: 12,
          color: isResolved ? Colors.grey.shade600 : color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateNoteScreen(),
              ),
            );
            if (result == true) {
              _loadNotes();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 24),
              SizedBox(width: 8),
              Text(
                '写下你的烦恼',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
