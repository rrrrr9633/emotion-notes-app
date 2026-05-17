# 情绪便利贴 App

一个帮助情侣化解矛盾的情绪管理应用。

## 技术栈

- **前端**: Flutter
- **后端**: Python + FastAPI
- **数据库**: MongoDB
- **AI**: OpenAI API / 国内大模型

## 项目结构

```
emotion_notes_app/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── providers/                   # 状态管理
│   │   ├── auth_provider.dart       # 认证状态
│   │   └── game_provider.dart       # 游戏进度
│   ├── screens/                     # 页面
│   │   ├── splash_screen.dart       # 启动页
│   │   ├── welcome_animation_screen.dart  # 欢迎动画
│   │   ├── auth/                    # 认证相关
│   │   │   ├── login_screen.dart    # 登录页
│   │   │   ├── register_screen.dart # 注册页
│   │   │   └── partner_bind_screen.dart  # 情侣绑定页
│   │   ├── game/                    # 游戏相关
│   │   │   └── game_screen.dart     # 闯关游戏
│   │   └── home/                    # 主页相关
│   │       └── home_screen.dart     # 便利贴主页
│   └── services/                    # 服务层
│       └── api_service.dart         # API接口
└── pubspec.yaml                     # 依赖配置
```

## 快速开始

### 1. 安装依赖

```bash
cd emotion_notes_app
flutter pub get
```

### 2. 配置后端地址

编辑 `lib/services/api_service.dart`，修改服务器地址：

```dart
static const String baseUrl = 'http://your-server-ip:8000/api';
```

### 3. 运行应用

```bash
flutter run
```

## 添加图片资源

### 方法1: 添加静态图片

1. 在项目根目录创建资源文件夹：
```bash
mkdir -p assets/images
mkdir -p assets/animations
mkdir -p assets/models
```

2. 将图片文件放入对应文件夹

3. 在代码中使用：
```dart
Image.asset('assets/images/your_image.png')
```

### 方法2: 添加Lottie动画

1. 从 [LottieFiles](https://lottiefiles.com/) 下载JSON动画文件

2. 放入 `assets/animations/` 文件夹

3. 在代码中使用：
```dart
import 'package:lottie/lottie.dart';

Lottie.asset('assets/animations/your_animation.json')
```

### 方法3: 添加3D模型（需要额外插件）

可以使用 `flutter_3d_obj` 或 `model_viewer_plus` 插件来显示3D模型。

## 需要替换图片的位置

在代码中搜索 `TODO:` 注释，这些位置预留了图片/模型的位置：

1. **启动页** (`splash_screen.dart`) - Logo位置
2. **登录页** (`login_screen.dart`) - Logo位置
3. **注册页** (`register_screen.dart`) - Logo位置
4. **绑定页** (`partner_bind_screen.dart`) - 可爱风图片
5. **欢迎动画** (`welcome_animation_screen.dart`) - 欢迎动画
6. **游戏页** (`game_screen.dart`) - 游戏内容图片/模型

## 应用流程

1. **启动页** → 检查登录状态
2. **未登录** → 登录/注册页 → 情侣绑定
3. **已登录已绑定** → 欢迎动画
4. **检查闯关状态**:
   - 未完成 → 闯关游戏
   - 已完成 → 便利贴主页

## 待开发功能

- [ ] 完善游戏关卡内容
- [ ] 实现便利贴CRUD功能
- [ ] 集成AI回复功能
- [ ] 添加情绪统计
- [ ] 双人协作模式

## 注意事项

- 记得在 `pubspec.yaml` 中取消注释 assets 部分
- 首次运行需要连接设备或启动模拟器
- 后端API需要先部署才能正常使用
