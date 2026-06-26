# 笔程打卡 (BiCheng Punch)

> 一款面向备考人群的轻量级打卡 App，帮助你在考研、考公、教资等备考路上保持习惯、专注学习。

## 项目简介

**笔程打卡** 是一个基于 Flutter 开发的跨平台移动应用，专注于解决备考过程中的三个核心需求：

- **习惯养成** — 创建学习习惯，每日打卡追踪
- **专注计时** — 番茄钟 + 白噪音，提升学习效率
- **数据统计** — 可视化图表直观展示学习进度

同时提供本地 Python 后端服务器，支持多设备间的数据同步。

## 功能模块

| 模块 | 页面 | 功能描述 |
|------|------|----------|
| 📋 **首页** | `/home` | 今日打卡概览，卡片式布局一键打卡 |
| ⏱ **专注** | `/focus` | 番茄钟 / 倒计时专注模式，白噪音背景音 |
| 📊 **统计** | `/stats` | 周期完成率、累计时长、习惯热力图等图表 |
| 📁 **模板** | `/group` | 备考计划模板，快速创建习惯 |
| 👤 **我的** | `/profile` | 个人设置、补签管理、云端同步 |
| 🔐 **登录** | `/login` | 账号登录，跨设备数据同步 |

## 技术栈

### 前端（Flutter）

| 技术 | 用途 |
|------|------|
| **Flutter 3.x** + **Dart 3.x** | 跨平台 UI 框架 |
| **Provider** | 状态管理（主题、习惯、打卡、专注、统计各模块独立 Provider） |
| **Hive** + **Hive Flutter** | 本地持久化存储 |
| **flutter_local_notifications** | 本地通知提醒（打卡/专注结束） |
| **wakelock_plus** | 专注页屏幕常亮 |
| **audioplayers** | 白噪音与提示音播放 |
| **home_widget** | 桌面小组件，一键快捷打卡 |
| **http** | 与本地后端通信，数据同步 |
| **Material 3** | Material You 设计语言 |

### 后端（Python）

| 技术 | 用途 |
|------|------|
| **Python 3** | 本地轻量后端服务器 |
| **SQLite** | 用户数据存储 |
| **http.server** | 标准库 HTTP 服务，零依赖 |

## 项目结构

```
├── lib/
│   ├── main.dart                 # 应用入口，Provider 注入
│   ├── models/                   # 数据模型（Hive TypeAdapter）
│   │   ├── habit_model.dart      # 习惯模型
│   │   ├── check_in_model.dart   # 打卡记录模型
│   │   ├── focus_record_model.dart # 专注记录模型
│   │   └── models.dart           # 模型统一导出
│   ├── providers/                # 状态管理
│   │   ├── theme_provider.dart   # 主题模式
│   │   ├── habit_provider.dart   # 习惯数据
│   │   ├── check_in_provider.dart # 打卡记录
│   │   ├── focus_provider.dart   # 专注计时
│   │   ├── stats_provider.dart   # 统计数据
│   │   └── login_provider.dart   # 登录/同步
│   ├── pages/                    # 页面
│   │   ├── home/                 # 首页（今日打卡概览）
│   │   ├── focus/                # 专注模块（番茄钟/计时）
│   │   ├── stats/                # 统计页
│   │   ├── group/                # 模板页
│   │   ├── profile/              # 我的页
│   │   └── login/                # 登录页
│   ├── widgets/                  # 可复用组件
│   │   ├── habit_card.dart       # 习惯打卡卡片
│   │   ├── month_calendar.dart   # 月历视图
│   │   ├── calendar_heatmap_widget.dart # 热力图
│   │   ├── line_chart_widget.dart # 折线图
│   │   ├── pie_chart_widget.dart # 饼图
│   │   ├── focus_timer_ring.dart # 专注倒计时环形进度
│   │   └── main_shell.dart       # 底部导航框架
│   ├── services/                 # 服务层
│   │   ├── storage_service.dart  # Hive 存储初始化
│   │   ├── audio_service.dart    # 音频播放管理
│   │   ├── widget_service.dart   # 桌面小组件管理
│   │   └── template_service.dart # 备考模板服务
│   ├── routes/                   # 路由配置
│   │   ├── app_router.dart       # 路由生成器
│   │   └── app_routes.dart       # 命名路由常量
│   ├── theme/                    # 主题配置
│   │   ├── app_colors.dart       # 颜色常量
│   │   └── app_theme.dart        # 亮/暗主题定义
│   └── utils/                    # 工具函数
│       ├── app_utils.dart
│       ├── stats_utils.dart
│       └── timer_utils.dart
├── assets/audio/                 # 白噪音与提示音资源
├── server/                       # Python 本地后端
│   ├── server.py                 # HTTP API 服务器
│   ├── server.db                 # SQLite 数据库
│   └── users.json                # 用户数据（备用）
├── android/                      # Android 原生配置
├── ios/                          # iOS 原生配置
├── start_server.bat              # Windows 一键启动后端
├── pubspec.yaml                  # Flutter 依赖配置
└── docs/superpowers/plans/       # 开发计划与文档
```

## 快速开始

### 环境要求

- Flutter SDK >= 3.0
- Dart SDK >= 3.0
- Python 3.x（可选，用于数据同步）

### 安装与运行

```bash
# 1. 克隆项目
git clone https://github.com/bluebighead/bicheng-punch.git
cd bicheng-punch

# 2. 安装 Flutter 依赖
flutter pub get

# 3. 启动后端服务器（可选，用于多设备同步）
python server/server.py

# 4. 运行应用
flutter run
```

> 如需打包 APK：`flutter build apk --release`

## 设计理念

### 反焦虑设计
- **弱化连续天数**，突出累计完成率
- **休息日不计入统计**，放松一下也没关系
- 打卡后提供 **轻微震动反馈**，减少视觉负担

### 无打扰专注
- 专注页保持 **屏幕常亮**，避免学习中息屏打断
- **白噪音** 帮助进入心流状态
- 极简界面，无推送干扰

### 本地优先 + 可选云同步
- 所有数据优先存储在本地（Hive）
- 可选的 Python 后端实现局域网数据同步
- 支持桌面小组件一键打卡

## 本地后端 API

启动 `server/server.py` 后，默认监听 `0.0.0.0:5678`：

| 接口 | 方法 | 功能 |
|------|------|------|
| `/login` | POST | 用户登录验证 |
| `/sync` | POST | 习惯/打卡数据同步上传 |
| `/sync/download` | GET | 从服务端拉取数据 |
| `/user/info` | GET | 获取用户信息（补签额度等） |

## 截图

<!-- 项目暂无截图，欢迎贡献 -->

## 许可

本项目仅供个人学习使用。
