import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../welcome_animation_screen.dart';
import 'login_screen.dart';

class PartnerBindScreen extends StatefulWidget {
  const PartnerBindScreen({super.key});

  @override
  State<PartnerBindScreen> createState() => _PartnerBindScreenState();
}

class _PartnerBindScreenState extends State<PartnerBindScreen> {
  final _partnerUsernameController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _pendingRequests = [];
  bool _isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
    // 每5秒自动刷新一次
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _loadPendingRequests();
        _startAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _partnerUsernameController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _isLoadingRequests = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.getPendingBindRequests();
    
    print('获取绑定请求结果: $result');
    
    setState(() {
      _isLoadingRequests = false;
      if (result['success']) {
        _pendingRequests = result['requests'] ?? [];
        print('待处理请求数量: ${_pendingRequests.length}');
      }
    });
  }

  Future<void> _acceptBindRequest(String requestId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.acceptBindRequest(requestId);
    
    if (!mounted) return;
    
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('绑定成功！'),
          backgroundColor: Colors.green.shade400,
        ),
      );
      
      // 跳转到欢迎动画
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeAnimationScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '接受失败'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    
    if (!mounted) return;
    
    // 跳转到登录页面
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _sendBindRequest() async {
    if (_partnerUsernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入对方的用户名')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.sendBindRequest(
      _partnerUsernameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      _partnerUsernameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('绑定请求已发送，等待对方同意'),
          backgroundColor: Colors.green.shade400,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '发送失败'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFF6B9D)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('退出登录'),
                  content: const Text('确定要退出登录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                _logout();
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE5EC),
              Color(0xFFFFF0F5),
              Color(0xFFFFE5F0),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // TODO: 可爱风图片位置
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Color(0xFFFF6B9D),
                  ),
                ),
                const SizedBox(height: 30),
                
                const Text(
                  '绑定情侣账号',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B9D),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '输入对方的用户名发送绑定请求',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.pink.shade300,
                  ),
                ),
                const SizedBox(height: 40),
                
                // 输入对方用户名
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _partnerUsernameController,
                    decoration: InputDecoration(
                      labelText: '对方的用户名',
                      labelStyle: TextStyle(color: Colors.pink.shade300),
                      prefixIcon: const Icon(Icons.person_add, color: Color(0xFFFF6B9D)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // 发送绑定请求按钮
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendBindRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B9D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '发送绑定请求',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                
                const Divider(),
                const SizedBox(height: 20),
                
                Text(
                  '待处理的绑定请求',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade400,
                  ),
                ),
                const SizedBox(height: 20),
                
                // 待处理的绑定请求列表
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isLoadingRequests
                        ? const Center(child: CircularProgressIndicator())
                        : _pendingRequests.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 64,
                                      color: Colors.pink.shade200,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '暂无待处理请求',
                                      style: TextStyle(
                                        color: Colors.pink.shade200,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: _loadPendingRequests,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('刷新'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFFFF6B9D),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _pendingRequests.length,
                                itemBuilder: (context, index) {
                                  final request = _pendingRequests[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 0,
                                    color: const Color(0xFFFFF0F5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFFF6B9D),
                                        child: Text(
                                          request['from_username'][0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      title: Text(
                                        request['from_username'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF6B9D),
                                        ),
                                      ),
                                      subtitle: const Text('想要与你绑定'),
                                      trailing: ElevatedButton(
                                        onPressed: () => _acceptBindRequest(request['_id']),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF6B9D),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text('接受'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
