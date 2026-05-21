import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Map<String, dynamic>? _note;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isResolving = false;
  bool _isAddingComment = false;
  bool _isPlayingAudio = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  final Map<String, Color> _emotionColors = {
    '生气': const Color(0xFFFF6B6B),
    '难过': const Color(0xFF4ECDC4),
    '委屈': const Color(0xFFFFE66D),
    '失望': const Color(0xFF95E1D3),
    '焦虑': const Color(0xFFFFA07A),
  };

  @override
  void initState() {
    super.initState();
    _loadNoteDetail();
    
    // 监听音频播放状态
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = state == PlayerState.playing;
        });
      }
    });
    
    // 监听音频时长
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _audioDuration = duration;
        });
      }
    });
    
    // 监听播放进度
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _audioPosition = position;
        });
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadNoteDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        throw Exception('用户未登录');
      }

      final result = await _apiService.getNoteDetail(
        noteId: widget.noteId,
        userId: userId,
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _note = result['note'];
          _isLoading = false;
        });
        
        // 加载留言
        await _loadComments();
      } else {
        throw Exception(result['message'] ?? '加载失败');
      }
    } catch (e) {
      print('加载便利贴详情失败: $e');
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

  Future<void> _loadComments() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) return;

      final result = await _apiService.getComments(
        noteId: widget.noteId,
        userId: userId,
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(result['comments'] ?? []);
        });
      }
    } catch (e) {
      print('加载留言失败: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isAddingComment = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        throw Exception('用户未登录');
      }

      final result = await _apiService.addComment(
        noteId: widget.noteId,
        userId: userId,
        content: _commentController.text.trim(),
      );

      if (result['success'] == true && mounted) {
        _commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('留言成功 💬'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 刷新留言列表
        await _loadComments();
      } else {
        throw Exception(result['message'] ?? '留言失败');
      }
    } catch (e) {
      print('添加留言失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('留言失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingComment = false;
        });
      }
    }
  }

  Future<void> _markResolved() async {
    if (_note == null) return;

    setState(() {
      _isResolving = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        throw Exception('用户未登录');
      }

      final result = await _apiService.markNoteResolved(
        noteId: widget.noteId,
        userId: userId,
      );

      if (result['success'] == true && mounted) {
        // 检查是否升级
        final levelUp = result['level_up'] == true;

        if (levelUp) {
          _showLevelUpDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已标记为消气 ✨'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // 刷新详情
        await _loadNoteDetail();
        
        // 通知列表页刷新
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception(result['message'] ?? '操作失败');
      }
    } catch (e) {
      print('标记消气失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  void _showLevelUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎉',
              style: TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 16),
            const Text(
              '恭喜升级！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '你的虚拟宠物长大了一点！',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('太棒了！'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除便利贴'),
        content: const Text('确定要删除这张便利贴吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        throw Exception('用户未登录');
      }

      final result = await _apiService.deleteNote(
        noteId: widget.noteId,
        userId: userId,
      );

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('便利贴已删除'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception(result['message'] ?? '删除失败');
      }
    } catch (e) {
      print('删除便利贴失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAudioPlayback() async {
    if (_note == null || _note!['audio_url'] == null) return;

    try {
      if (_isPlayingAudio) {
        await _audioPlayer.pause();
      } else {
        final audioUrl = ApiService.resolveMediaUrl(_note!['audio_url']);
        if (audioUrl != null) {
          await _audioPlayer.play(UrlSource(audioUrl));
        }
      }
    } catch (e) {
      print('播放音频失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_note != null && _note!['is_resolved'] != true)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteNote,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _note == null
              ? const Center(child: Text('便利贴不存在'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final note = _note!;
    final isResolved = note['is_resolved'] == true;
    final createdAt = DateTime.parse(note['created_at']);
    final emotionTag = note['emotion_tag'] ?? '情绪';
    final color = _emotionColors[emotionTag] ?? Colors.grey;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 情绪标签和时间
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isResolved ? Colors.grey.shade200 : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isResolved ? Colors.grey.shade400 : color,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  emotionTag,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isResolved ? Colors.grey.shade600 : color,
                  ),
                ),
              ),
              const Spacer(),
              if (isResolved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '已消气',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            DateFormat('yyyy年MM月dd日 HH:mm').format(createdAt),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 24),

          // 标题（如果有）
          if (note['title'] != null && note['title'].toString().isNotEmpty) ...[
            Text(
              note['title'],
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isResolved ? Colors.grey.shade600 : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 内容
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isResolved ? Colors.grey.shade50 : const Color(0xFFFFFAF0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isResolved ? Colors.grey.shade200 : Colors.grey.shade300,
              ),
            ),
            child: Text(
              note['content'] ?? '',
              style: TextStyle(
                fontSize: 16,
                height: 1.8,
                color: isResolved ? Colors.grey.shade600 : Colors.black87,
              ),
            ),
          ),

          // 音频播放器
          if (note['audio_url'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _toggleAudioPlayback,
                    icon: Icon(
                      _isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      size: 40,
                      color: const Color(0xFFFF6B9D),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: _audioDuration.inMilliseconds > 0
                              ? _audioPosition.inMilliseconds / _audioDuration.inMilliseconds
                              : 0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_audioPosition),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _formatDuration(_audioDuration),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.mic,
                    color: Color(0xFFFF6B9D),
                    size: 20,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // AI回复
          if (note['ai_reply'] != null) ...[
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B9D), Color(0xFFFFC371)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('💕', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AURA的回复',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF6B9D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isResolved
                    ? Colors.grey.shade50
                    : const Color(0xFFFFF5F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isResolved
                      ? Colors.grey.shade200
                      : const Color(0xFFFF6B9D).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Text(
                note['ai_reply'],
                style: TextStyle(
                  fontSize: 15,
                  height: 1.8,
                  color: isResolved
                      ? Colors.grey.shade600
                      : const Color(0xFFFF6B9D),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // 已消气按钮
          if (!isResolved)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isResolving ? null : _markResolved,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isResolving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '我已经消气了',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          
          const SizedBox(height: 32),
          
          // 留言区域
          const Divider(),
          const SizedBox(height: 16),
          
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '留言',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 留言输入框
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: '写下你的想法...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _isAddingComment ? null : _addComment,
                icon: _isAddingComment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 留言列表
          if (_comments.isNotEmpty) ...[
            ..._comments.map((comment) => _buildCommentItem(comment)),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  '还没有留言',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final createdAt = DateTime.parse(comment['created_at']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: comment['user_avatar'] != null
                    ? NetworkImage(comment['user_avatar'])
                    : null,
                child: comment['user_avatar'] == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                comment['user_name'] ?? '未知',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MM-dd HH:mm').format(createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment['content'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
