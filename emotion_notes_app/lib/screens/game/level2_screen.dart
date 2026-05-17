import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../widgets/music_player.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'level3_screen.dart';

class Level2Screen extends StatefulWidget {
  const Level2Screen({super.key});

  @override
  State<Level2Screen> createState() => _Level2ScreenState();
}

class _Level2ScreenState extends State<Level2Screen>
    with TickerProviderStateMixin {
  File? _selectedImage;
  String? _imageUrl; // 云端图片URL
  final ImagePicker _picker = ImagePicker();
  
  String? _selectedColor;
  final _dialogueController = TextEditingController();
  final _songController = TextEditingController();
  final _photoDescriptionController = TextEditingController(); // 新增：照片描述
  
  late AnimationController _envelopeController;
  late AnimationController _fadeController;
  late Animation<double> _envelopeAnimation;
  
  bool _showPhoto = false;
  bool _showInputs = false;
  bool _isLoadingBlessing = false;
  bool _isUploadingPhoto = false;
  
  final ApiService _apiService = ApiService();
  
  final List<Map<String, dynamic>> _colorOptions = [
    {'name': '雾蓝色', 'color': const Color(0xFF9DB4C0)},
    {'name': '奶白色', 'color': const Color(0xFFF5F5DC)},
    {'name': '浅粉色', 'color': const Color(0xFFFFB6C1)},
    {'name': '薄荷绿', 'color': const Color(0xFF98D8C8)},
    {'name': '淡黄色', 'color': const Color(0xFFFFF8DC)},
    {'name': '浅灰色', 'color': const Color(0xFFD3D3D3)},
  ];

  @override
  void initState() {
    super.initState();
    
    _envelopeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _envelopeAnimation = CurvedAnimation(
      parent: _envelopeController,
      curve: Curves.easeOutBack,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _envelopeController.dispose();
    _fadeController.dispose();
    _dialogueController.dispose();
    _songController.dispose();
    _photoDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _isUploadingPhoto = true;
      });
      
      // 上传图片到云端服务器
      try {
        final result = await _apiService.uploadLevel2Photo(image.path);
        
        if (result['success'] == true) {
          setState(() {
            _imageUrl = result['photo_url'];
            _isUploadingPhoto = false;
          });
          
          // 播放信封打开动画
          await Future.delayed(const Duration(milliseconds: 300));
          _envelopeController.forward();
          
          await Future.delayed(const Duration(milliseconds: 800));
          setState(() {
            _showPhoto = true;
          });
          
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {
            _showInputs = true;
          });
          _fadeController.forward();
        } else {
          setState(() {
            _isUploadingPhoto = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('上传失败: ${result['message']}')),
            );
          }
        }
      } catch (e) {
        setState(() {
          _isUploadingPhoto = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: $e')),
          );
        }
      }
    }
  }

  String _generateDescription() {
    if (_selectedColor == null || 
        _dialogueController.text.isEmpty || 
        _songController.text.isEmpty) {
      return '';
    }
    
    return '那天你穿着$_selectedColor，你说"${_dialogueController.text}"，我的手机正好循环到《${_songController.text}》。';
  }

  Future<void> _completeLevel() async {
    setState(() {
      _isLoadingBlessing = true;
    });

    try {
      final result = await _apiService.getLevel2Blessing(
        color: _selectedColor!,
        dialogue: _dialogueController.text,
        song: _songController.text,
        photoUrl: _imageUrl ?? '',
      );

      if (mounted) {
        setState(() {
          _isLoadingBlessing = false;
        });

        if (result['success'] == true) {
          await _showBlessingDialog(
            result['blessing'] ?? '照片会褪色，但那天你说话的语气不会。我们已经把它保存在这里了。💕',
            result['description'] ?? _generateDescription(),
            _photoDescriptionController.text,
          );
        } else {
          await _showBlessingDialog(
            '照片会褪色，但那天你说话的语气不会。我们已经把它保存在这里了。💕',
            _generateDescription(),
            _photoDescriptionController.text,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBlessing = false;
        });
        await _showBlessingDialog(
          '照片会褪色，但那天你说话的语气不会。我们已经把它保存在这里了。💕',
          _generateDescription(),
          _photoDescriptionController.text,
        );
      }
    }
  }

  Future<void> _saveLevel2Data(String blessing) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      
      if (userId == null) return;

      await _apiService.saveLevel2Data(
        userId: userId,
        color: _selectedColor!,
        dialogue: _dialogueController.text,
        song: _songController.text,
        photoUrl: _imageUrl ?? '',
        blessing: blessing,
      );
      
      print('第二关数据已保存');
    } catch (e) {
      print('保存第二关数据失败: $e');
    }
  }

  Future<void> _showBlessingDialog(String blessing, String description, String photoDescription) async {
    // 异步保存第二关数据到后端（不阻塞UI）
    _saveLevel2Data(blessing);
    
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
                  colors: [Color(0xFFFFB6C1), Color(0xFFFFC0CB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB6C1).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '📸',
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
                color: Color(0xFFFFB6C1),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 自动生成的描述
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.black87,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // 用户写的照片描述
                  const Text(
                    '你的描述：',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    photoDescription,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // AI祝福
                  Text(
                    blessing,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                  // 跳转到第三关
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const Level3Screen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB6C1),
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
      backgroundColor: const Color(0xFFFFF5F7),
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
                  child: (_selectedImage == null && !_showInputs)
                      ? _buildUploadPrompt()
                      : _buildPhotoContent(),
                ),
                
                // 底部按钮
                if (_showInputs) _buildBottomButton(),
              ],
            ),
          ),
          
          // 音乐播放器
          MusicPlayer(
            themeColor: const Color(0xFFFFB6C1),
            level: 2,
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
            '第二关：记忆',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFB6C1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '温柔的、带一点点模糊滤镜的收藏夹',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
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
                children: [
                  const Text(
                    '📸',
                    style: TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '选一张你们之间最特别的照片',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '不是最美的那张，\n是最让你心头一软的那张。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('选择照片'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB6C1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  
                  // Web平台提示和跳过按钮
                  if (kIsWeb) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Web版暂不支持图片上传',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _skipPhotoUpload,
                      child: const Text(
                        '跳过上传，继续填写 →',
                        style: TextStyle(
                          color: Color(0xFFFFB6C1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 跳过照片上传（仅Web平台）
  void _skipPhotoUpload() async {
    setState(() {
      _showPhoto = true;
      _showInputs = true;
    });
    _fadeController.forward();
  }

  Widget _buildPhotoContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // 信封动画 + 照片
          _buildEnvelopePhoto(),
          
          if (_showInputs) ...[
            const SizedBox(height: 32),
            
            // 三个填空
            _buildInputFields(),
            
            const SizedBox(height: 24),
            
            // 生成的描述
            if (_generateDescription().isNotEmpty)
              _buildGeneratedDescription(),
            
            const SizedBox(height: 100), // 为底部按钮留空间
          ],
        ],
      ),
    );
  }

  Widget _buildEnvelopePhoto() {
    return AnimatedBuilder(
      animation: _envelopeAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            maxWidth: 400,
            minHeight: 300,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 信封背景（如果没有照片，显示占位图）
              if (!_showPhoto || _selectedImage == null)
                Container(
                  width: 300,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFB6C1),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '💌',
                      style: TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              
              // 上传中提示
              if (_isUploadingPhoto)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFFFB6C1),
                      ),
                      SizedBox(height: 12),
                      Text('正在上传照片...'),
                    ],
                  ),
                ),
              
              // 照片（只在有图片时显示）
              if (_showPhoto && !_isUploadingPhoto && _selectedImage != null)
                FadeTransition(
                  opacity: _fadeController,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildImageWidget(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageWidget() {
    if (kIsWeb) {
      // Web 平台：由于无法直接使用本地文件，显示占位图
      // 实际项目中应该上传到服务器后使用服务器URL
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 400,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library,
              size: 64,
              color: Color(0xFFFFB6C1),
            ),
            const SizedBox(height: 16),
            const Text(
              '照片已上传',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '(Web版暂不支持预览)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    } else {
      // 移动端使用 Image.file
      if (_selectedImage != null) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            maxWidth: 400,
            maxHeight: 400,
          ),
          child: Image.file(
            _selectedImage!,
            fit: BoxFit.contain,
          ),
        );
      }
    }
    
    return Container(
      width: 300,
      height: 300,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image, size: 48, color: Colors.grey),
      ),
    );
  }

  Widget _buildInputFields() {
    return FadeTransition(
      opacity: _fadeController,
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
            // 颜色选择
            const Text(
              '那天，她/他穿的什么颜色？',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorOptions.map((colorOption) {
                final isSelected = _selectedColor == colorOption['name'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorOption['name'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorOption['color']
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? colorOption['color']
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: colorOption['color'],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          colorOption['name'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // 台词输入
            const Text(
              '拍这张照片时，你们正在说什么？',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dialogueController,
              decoration: InputDecoration(
                hintText: '简短台词...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFFB6C1),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            
            const SizedBox(height: 24),
            
            // 歌曲输入
            const Text(
              '如果这张照片有背景音乐，是哪首歌？',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _songController,
              decoration: InputDecoration(
                hintText: '歌曲名称...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFFB6C1),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            
            const SizedBox(height: 24),
            
            // 照片描述输入（新增）
            const Text(
              '用一段话描述这张照片（至少30字）',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '可以写下当时的场景、心情、或者这张照片对你的意义...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _photoDescriptionController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '写下你对这张照片的描述...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFFB6C1),
                    width: 2,
                  ),
                ),
                counterText: '${_photoDescriptionController.text.length}/200 (最少30字)',
                counterStyle: TextStyle(
                  color: _photoDescriptionController.text.length >= 30
                      ? Colors.green
                      : Colors.grey,
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

  Widget _buildGeneratedDescription() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFB6C1).withOpacity(0.1),
            const Color(0xFFFFC0CB).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB6C1).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFFFB6C1),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '生成的记忆',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _generateDescription(),
            style: const TextStyle(
              fontSize: 16,
              height: 1.8,
              color: Colors.black87,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final canProceed = _selectedColor != null &&
        _dialogueController.text.isNotEmpty &&
        _songController.text.isNotEmpty &&
        _photoDescriptionController.text.length >= 30; // 至少30字
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: (canProceed && !_isLoadingBlessing)
              ? _completeLevel
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB6C1),
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
