import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class CreateNoteScreen extends StatefulWidget {
  const CreateNoteScreen({super.key});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedEmotion = '生气';
  bool _isSubmitting = false;
  bool _isGeneratingAI = false;
  
  final ApiService _apiService = ApiService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  bool _isRecording = false;
  String? _audioPath;
  String? _audioUrl;
  
  final List<String> _emotions = ['生气', '难过', '委屈', '失望', '焦虑'];
  
  final Map<String, Color> _emotionColors = {
    '生气': const Color(0xFFFF6B6B),
    '难过': const Color(0xFF4ECDC4),
    '委屈': const Color(0xFFFFE66D),
    '失望': const Color(0xFF95E1D3),
    '焦虑': const Color(0xFFFFA07A),
  };

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        
        setState(() {
          _isRecording = true;
          _audioPath = path;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限')),
          );
        }
      }
    } catch (e) {
      print('开始录音失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      
      if (path != null && mounted) {
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });
        
        // 上传音频
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在上传语音...')),
        );
        
        final result = await _apiService.uploadAudio(path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          if (result['success'] == true) {
            setState(() {
              _audioUrl = result['audio_url'];
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('语音上传成功 🎤'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? '上传失败'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('停止录音失败: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e')),
        );
      }
    }
  }

  void _deleteAudio() {
    setState(() {
      _audioPath = null;
      _audioUrl = null;
    });
  }

  Future<void> _submitNote() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请写下你的烦恼')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isGeneratingAI = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        throw Exception('用户未登录');
      }

      // 显示AI生成中的提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('AURA正在思考...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final result = await _apiService.createNote(
        userId: userId,
        content: _contentController.text.trim(),
        emotionTag: _selectedEmotion,
        title: _titleController.text.trim().isEmpty 
            ? null 
            : _titleController.text.trim(),
        audioUrl: _audioUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('便利贴创建成功 💕'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // 返回true表示需要刷新列表
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '创建失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('创建便利贴失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isGeneratingAI = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '写下你的烦恼',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题输入（可选）
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '标题（可选）',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: '给这个烦恼起个名字...',
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
            ),
            
            const SizedBox(height: 20),
            
            // 内容输入
            TextField(
              controller: _contentController,
              maxLines: 8,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: '详细描述',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: '写下让你不开心的事情...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 语音录制区域
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mic, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        '语音便利贴（可选）',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_audioUrl != null) ...[
                    // 已录制的音频
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '语音已录制',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: _deleteAudio,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_isRecording) ...[
                    // 录音中
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '录音中...',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _stopRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('停止'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 未录制
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.mic),
                        label: const Text('按住录音'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 情绪标签选择
            const Text(
              '选择情绪',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _emotions.map((emotion) {
                final isSelected = _selectedEmotion == emotion;
                final color = _emotionColors[emotion] ?? Colors.grey;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedEmotion = emotion;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: color,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      emotion,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            
            // AI提示
            if (_isGeneratingAI)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AURA正在为你生成暖心回复...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFF6B9D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // 提交按钮
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '提交',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 提示文字
            Center(
              child: Text(
                'AURA会用温暖的话语陪伴你 💕',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
