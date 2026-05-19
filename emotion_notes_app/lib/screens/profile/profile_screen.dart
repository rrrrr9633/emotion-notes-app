import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'memories_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _partnerInfo;
  Map<String, dynamic>? _unbindStatus;
  bool _isLoading = true;
  int _daysTogeth = 0;
  
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }
  
  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      
      if (userId == null) return;
      
      // 获取用户信息
      final userResult = await _apiService.getUserProfile(userId);
      if (userResult['success'] == true) {
        _userInfo = _normalizeUserMediaUrls(userResult['user']);
        
        // 如果有伴侣，获取伴侣信息
        if (_userInfo!['partner_id'] != null) {
          final partnerResult = await _apiService.getUserProfile(_userInfo!['partner_id']);
          if (partnerResult['success'] == true) {
            _partnerInfo = _normalizeUserMediaUrls(partnerResult['user']);
          }
          
          // 计算在一起的天数
          if (_userInfo!['relationship_start_date'] != null) {
            final startDate = DateTime.parse(_userInfo!['relationship_start_date']);
            _daysTogeth = DateTime.now().difference(startDate).inDays;
          }
          
          // 获取解绑状态
          final unbindResult = await _apiService.getUnbindStatus(userId);
          if (unbindResult['success'] == true) {
            _unbindStatus = unbindResult;
          }
        }
      }
    } catch (e) {
      print('加载用户信息失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Map<String, dynamic> _normalizeUserMediaUrls(Map<String, dynamic> user) {
    final normalized = Map<String, dynamic>.from(user);
    final avatarUrl = normalized['avatar_url'] as String?;
    if (avatarUrl != null) {
      normalized['avatar_url'] = ApiService.resolveMediaUrl(avatarUrl);
    }
    return normalized;
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      
      if (userId == null) return;
      
      // 显示上传中
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在上传头像...')),
        );
      }
      
      // 上传头像
      final result = await _apiService.uploadAvatar(
        userId,
        image.path,
        filename: image.name,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _userInfo = {
              ...?_userInfo,
              'avatar_url': result['avatar_url'],
            };
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('头像更新成功 💕')),
          );
          _loadUserInfo(); // 刷新信息
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '上传失败')),
          );
        }
      }
    } catch (e) {
      print('上传头像失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }
  
  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _userInfo?['nickname'] ?? '');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入新昵称',
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      await _updateNickname(result);
    }
  }
  
  Future<void> _updateNickname(String nickname) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      
      if (userId == null) return;
      
      final result = await _apiService.updateUserProfile(userId, nickname: nickname);
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('昵称更新成功 💕')),
          );
          _loadUserInfo();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '更新失败')),
          );
        }
      }
    } catch (e) {
      print('更新昵称失败: $e');
    }
  }
  
  Future<void> _requestUnbind() async {
    // 第一次确认
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确定要解绑吗？'),
        content: const Text('解绑后将开始24小时冷静期，期间可以取消解绑。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定解绑'),
          ),
        ],
      ),
    );
    
    if (confirm1 != true) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      
      if (userId == null) return;
      
      final result = await _apiService.requestUnbind(userId);
      
      if (mounted) {
        if (result['success'] == true) {
          // 显示对方的温柔话语
          final softWords = result['soft_words'] ?? '';
          
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Ta想对你说'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '💕',
                    style: TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    softWords.isNotEmpty ? softWords : '无论发生什么，我都爱你',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '24小时冷静期已开始',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadUserInfo();
                  },
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '操作失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('请求解绑失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _cancelUnbind() async {
    if (_unbindStatus == null || _unbindStatus!['request_id'] == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消解绑'),
        content: const Text('确定要取消解绑吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      
      if (userId == null) return;
      
      final result = await _apiService.cancelUnbind(
        requestId: _unbindStatus!['request_id'],
        userId: userId,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已取消解绑 💕'),
              backgroundColor: Colors.green,
            ),
          );
          _loadUserInfo();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '操作失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('取消解绑失败: $e');
    }
  }
  
  void _viewMemories() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MemoriesScreen(),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 顶部渐变背景
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: const Color(0xFFFF6B9D),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF6B9D),
                            Color(0xFFFFB6C1),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // 头像
                            GestureDetector(
                              onTap: _pickAndUploadAvatar,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _userInfo?['avatar_url'] != null
                                        ? NetworkImage(_userInfo!['avatar_url'])
                                        : null,
                                    child: _userInfo?['avatar_url'] == null
                                        ? const Icon(Icons.person, size: 50, color: Color(0xFFFF6B9D))
                                        : null,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 20,
                                        color: Color(0xFFFF6B9D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 昵称
                            Text(
                              _userInfo?['nickname'] ?? _userInfo?['username'] ?? '未设置',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // 内容区域
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // 解绑状态提示
                        if (_unbindStatus != null && _unbindStatus!['has_request'] == true) ...[
                          _buildUnbindBanner(),
                          const SizedBox(height: 16),
                        ],
                        
                        // 在一起的天数卡片
                        if (_partnerInfo != null) ...[
                          _buildTogetherCard(),
                          const SizedBox(height: 16),
                        ],
                        
                        // 个人信息卡片
                        _buildInfoCard(),
                        
                        const SizedBox(height: 16),
                        
                        // 伴侣信息卡片
                        if (_partnerInfo != null) _buildPartnerCard(),
                        
                        const SizedBox(height: 16),
                        
                        // 设置选项
                        _buildSettingsCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildUnbindBanner() {
    final remainingHours = _unbindStatus!['remaining_hours'] ?? 0;
    final hours = remainingHours.floor();
    final minutes = ((remainingHours - hours) * 60).floor();
    
    return GestureDetector(
      onTap: _viewMemories,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE4E1), Color(0xFFFFB6C1)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B9D).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  '解绑冷静期',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '剩余 ${hours}小时${minutes}分钟',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '点击查看你们的回忆',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cancelUnbind,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFF6B9D),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '取消解绑',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTogetherCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB6C1), Color(0xFFFFE4E1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B9D).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '💕',
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          const Text(
            '我们在一起',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_daysTogeth 天',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard() {
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
          const Text(
            '个人信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.person_outline,
            label: '昵称',
            value: _userInfo?['nickname'] ?? '未设置',
            onTap: _editNickname,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.account_circle_outlined,
            label: '用户名',
            value: _userInfo?['username'] ?? '',
          ),
        ],
      ),
    );
  }
  
  Widget _buildPartnerCard() {
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
          const Text(
            '我的另一半',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFFFF5F7),
                backgroundImage: _partnerInfo?['avatar_url'] != null
                    ? NetworkImage(_partnerInfo!['avatar_url'])
                    : null,
                child: _partnerInfo?['avatar_url'] == null
                    ? const Icon(Icons.person, size: 30, color: Color(0xFFFF6B9D))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _partnerInfo?['nickname'] ?? _partnerInfo?['username'] ?? '未知',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${_partnerInfo?['username'] ?? ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingsCard() {
    final hasUnbindRequest = _unbindStatus != null && _unbindStatus!['has_request'] == true;
    
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
          const Text(
            '设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // 查看回忆 - 始终显示（只要有伴侣）
          if (_partnerInfo != null) ...[
            _buildSettingItem(
              icon: Icons.photo_album,
              label: '查看回忆',
              onTap: _viewMemories,
            ),
            const Divider(height: 24),
          ],
          
          // 解绑选项 - 只在没有解绑请求时显示
          if (_partnerInfo != null && !hasUnbindRequest) ...[
            _buildSettingItem(
              icon: Icons.link_off,
              label: '解除绑定',
              onTap: _requestUnbind,
              textColor: Colors.orange,
            ),
            const Divider(height: 24),
          ],
          
          _buildSettingItem(
            icon: Icons.system_update,
            label: '检查更新',
            onTap: () {
              // TODO: 调用更新服务
            },
          ),
          const Divider(height: 24),
          _buildSettingItem(
            icon: Icons.logout,
            label: '退出登录',
            onTap: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            textColor: Colors.red,
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B9D)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: textColor ?? const Color(0xFFFF6B9D)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: textColor ?? Colors.black87,
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
