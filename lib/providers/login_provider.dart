import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

/// 登录状态管理 Provider
///
/// 职责：
/// 1. 管理登录/登出状态
/// 2. 与本地后端服务器通信，验证账号密码
/// 3. 记住密码功能（存储在 Hive configBox）
/// 4. 提供用户信息供其他页面使用
/// 5. 数据云同步：登录后自动拉取、登出时自动上传
class LoginProvider extends ChangeNotifier {
  // ===== 登录状态 =====
  bool _isLoggedIn = false; // 是否已登录
  bool _isLoading = false; // 是否正在请求
  bool _isSyncing = false; // 是否正在同步数据
  String? _token; // 登录令牌
  String? _username; // 用户名
  String? _displayName; // 显示名称
  String? _avatar; // 头像URL
  int _makeupQuotaPerMonth = 3; // 每月补签额度（从服务器获取）
  String? _errorMessage; // 错误信息

  // ===== 记住密码相关 =====
  bool _rememberPassword = false;
  String _savedUsername = '';
  String _savedPassword = '';

  /// 服务器地址（默认公网 cpolar 地址）
  String _serverHost = '3d5ccf47.r18.cpolar.top';
  int _serverPort = 80;

  // ===== 回调：用于同步后将数据导入到对应 Provider =====
  VoidCallback? _onSyncComplete;
  Future<void> Function(List<dynamic> habits)? _onHabitsReceived;
  Future<void> Function(List<dynamic> checkIns)? _onCheckInsReceived;

  /// 设置同步完成后的回调
  void setOnSyncComplete(VoidCallback callback) {
    _onSyncComplete = callback;
  }

  /// 设置接收到习惯数据后的回调（由外部注入，用于导入到 HabitProvider）
  void setOnHabitsReceived(Future<void> Function(List<dynamic> habits) callback) {
    _onHabitsReceived = callback;
  }

  /// 设置接收到打卡数据后的回调（由外部注入，用于导入到 CheckInProvider）
  void setOnCheckInsReceived(Future<void> Function(List<dynamic> checkIns) callback) {
    _onCheckInsReceived = callback;
  }

  // ===== Getter 方法 =====
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get token => _token;
  String? get username => _username;
  String? get displayName => _displayName;
  String? get avatar => _avatar;
  int get makeupQuotaPerMonth => _makeupQuotaPerMonth;
  String? get errorMessage => _errorMessage;
  bool get rememberPassword => _rememberPassword;
  String get savedUsername => _savedUsername;
  String get savedPassword => _savedPassword;
  String get serverHost => _serverHost;
  int get serverPort => _serverPort;

  /// 获取完整的服务器基础URL
  String get _baseUrl {
    if (_serverPort == 80) {
      return 'http://$_serverHost';
    }
    return 'http://$_serverHost:$_serverPort';
  }

  /// 初始化：从本地存储加载已保存的登录状态和记住密码信息
  Future<void> init() async {
    try {
      final box = StorageService.configBox;

      // 加载服务器地址配置
      _serverHost = box.get('server_host', defaultValue: '3d5ccf47.r18.cpolar.top') as String;
      _serverPort = box.get('server_port', defaultValue: 80) as int;

      // 加载记住密码信息
      _rememberPassword = box.get('remember_password', defaultValue: false) as bool;
      if (_rememberPassword) {
        _savedUsername = box.get('saved_username', defaultValue: '') as String;
        _savedPassword = box.get('saved_password', defaultValue: '') as String;
      }

      // 加载已保存的 Token，尝试恢复登录态
      final savedToken = box.get('login_token', defaultValue: '') as String;
      if (savedToken.isNotEmpty) {
        _token = savedToken;
        _isLoggedIn = true;
        // 尝试从服务器验证 Token 并获取用户信息
        final infoOk = await _fetchUserInfo();
        if (infoOk) {
          // Token 有效：从数据库同步完整数据（习惯、打卡、补签剩余额度）
          await syncFromServer();
        }
      }
    } catch (e) {
      debugPrint('LoginProvider 初始化失败: $e');
    }
  }

  /// 从服务器获取用户信息
  Future<bool> _fetchUserInfo() async {
    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/info'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 0) {
          final userData = data['data'];
          _username = userData['username'];
          _displayName = userData['displayName'];
          _avatar = userData['avatar'] ?? '';
          _makeupQuotaPerMonth = userData['makeupQuotaPerMonth'] ?? 3;
          // 注意：不要在这里同步额度到本地（_syncMakeupQuotaToLocal）
          // 因为 _fetchUserInfo 返回的是总额度，不是剩余额度
          // 剩余额度由后续的 syncFromServer() 从数据库同步
          notifyListeners();
          return true;
        }
      }

      // Token 失效，清除登录态
      _clearLoginState();
      return false;
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
      // 网络错误时保留登录状态，但标记为离线
      return false;
    }
  }

  /// 将服务器的补签额度同步到本地存储
  void _syncMakeupQuotaToLocal() {
    try {
      StorageService.setMonthlyMakeupQuota(_makeupQuotaPerMonth);
      debugPrint('已同步服务器补签额度到本地: $_makeupQuotaPerMonth');
    } catch (e) {
      debugPrint('同步补签额度到本地失败: $e');
    }
  }

  /// 用户登录
  Future<bool> login({
    required String username,
    required String password,
    required bool rememberPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 调用服务器登录接口
      final response = await http.post(
        Uri.parse('$_baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 0) {
          // 登录成功
          final loginData = data['data'];
          _token = loginData['token'];
          _username = loginData['username'];
          _displayName = loginData['displayName'];
          _avatar = loginData['avatar'] ?? '';
          _makeupQuotaPerMonth = loginData['makeupQuotaPerMonth'] ?? 3;
          _isLoggedIn = true;
          _rememberPassword = rememberPassword;

          // 保存 Token 到本地
          final box = StorageService.configBox;
          await box.put('login_token', _token);

          // 记住密码处理
          if (rememberPassword) {
            await box.put('remember_password', true);
            await box.put('saved_username', username);
            await box.put('saved_password', password);
          } else {
            await box.put('remember_password', false);
            await box.delete('saved_username');
            await box.delete('saved_password');
          }

          _isLoading = false;
          notifyListeners();
          debugPrint('用户 [$username] 登录成功');

          // 登录成功后自动从服务器拉取数据（包含补签剩余额度、习惯、打卡记录）
          await syncFromServer();
          return true;
        } else {
          _errorMessage = data['message'] ?? '登录失败';
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          _errorMessage = errorData['message'] ?? '登录失败';
        } catch (_) {
          _errorMessage = '服务器返回错误: ${response.statusCode}';
        }
      }
    } catch (e) {
      debugPrint('登录请求失败: $e');
      if (e is http.ClientException) {
        _errorMessage = '无法连接到服务器，请确保服务器已启动';
      } else {
        _errorMessage = '网络连接超时，请检查服务器状态';
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 登出
  Future<void> logout() async {
    // 登出前先上传本地数据到服务器
    await syncToServer();

    _clearLoginState();

    // 清除本地 Token
    try {
      final box = StorageService.configBox;
      await box.delete('login_token');
      if (!_rememberPassword) {
        await box.delete('saved_username');
        await box.delete('saved_password');
      }
    } catch (e) {
      debugPrint('登出时清除本地数据失败: $e');
    }

    notifyListeners();
    debugPrint('用户已登出');
  }

  /// 清除登录状态
  void _clearLoginState() {
    _isLoggedIn = false;
    _token = null;
    _username = null;
    _displayName = null;
    _avatar = null;
    _makeupQuotaPerMonth = 3;
    _errorMessage = null;
  }

  /// 更新服务器地址
  Future<void> updateServerConfig(String host, int port) async {
    _serverHost = host;
    _serverPort = port;

    try {
      final box = StorageService.configBox;
      await box.put('server_host', host);
      await box.put('server_port', port);
    } catch (e) {
      debugPrint('保存服务器配置失败: $e');
    }

    notifyListeners();
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ===== 数据同步方法 =====

  /// 从服务器拉取数据并返回
  ///
  /// 返回 { habits: [...], checkIns: [...] }
  /// 由调用方拿到数据后导入到对应 Provider
  Future<Map<String, dynamic>> fetchFromServer() async {
    if (_token == null) return {'habits': [], 'checkIns': []};

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/data/sync'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 0) {
          debugPrint('从服务器拉取数据成功');
          return data['data'] as Map<String, dynamic>? ?? {};
        }
      }
    } catch (e) {
      debugPrint('从服务器拉取数据失败: $e');
    }

    return {'habits': [], 'checkIns': []};
  }

  /// 上传数据到服务器
  ///
  /// [habits] 习惯列表 JSON（可选）
  /// [checkIns] 打卡记录列表 JSON（可选）
  Future<bool> pushToServer({
    List<Map<String, dynamic>>? habits,
    List<Map<String, dynamic>>? checkIns,
    int? makeupQuota,
  }) async {
    if (_token == null) return false;

    try {
      final body = <String, dynamic>{};
      if (habits != null) body['habits'] = habits;
      if (checkIns != null) body['checkIns'] = checkIns;
      if (makeupQuota != null) body['makeupQuota'] = makeupQuota;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/data/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('上传数据到服务器成功');
        return true;
      }
    } catch (e) {
      debugPrint('上传数据到服务器失败: $e');
    }

    return false;
  }

  /// 从服务器同步数据到本地 Provider（自动调用）
  Future<void> syncFromServer() async {
    _isSyncing = true;
    notifyListeners();

    final serverData = await fetchFromServer();
    final habits = serverData['habits'] as List<dynamic>? ?? [];
    final checkIns = serverData['checkIns'] as List<dynamic>? ?? [];

    debugPrint('从云端获取到 ${habits.length} 个习惯、${checkIns.length} 条打卡记录');

    // 同步云端补签额度（如果响应中包含）
    final makeupQuota = serverData['makeupQuota'];
    if (makeupQuota != null) {
      _makeupQuotaPerMonth = makeupQuota as int;
      _syncMakeupQuotaToLocal();
    }

    _isSyncing = false;
    _errorMessage = null;

    // 通过存储的回调将数据导入到对应 Provider
    if (habits.isNotEmpty && _onHabitsReceived != null) {
      await _onHabitsReceived!(habits);
    }
    if (checkIns.isNotEmpty && _onCheckInsReceived != null) {
      await _onCheckInsReceived!(checkIns);
    }

    notifyListeners();

    if (_onSyncComplete != null) {
      _onSyncComplete!();
    }
  }

  /// 上传本地数据到服务器（自动调用）
  ///
  /// [habits] 习惯 JSON 列表
  /// [checkIns] 打卡记录 JSON 列表
  Future<bool> syncToServer({
    List<Map<String, dynamic>>? habits,
    List<Map<String, dynamic>>? checkIns,
  }) async {
    if (!_isLoggedIn || _token == null) return false;

    // 自动附加当前补签剩余额度
    final remainingQuota = StorageService.getMonthlyMakeupQuota();

    final result = await pushToServer(
      habits: habits,
      checkIns: checkIns,
      makeupQuota: remainingQuota,
    );

    if (result) {
      debugPrint('本地数据已上传到服务器 (补签剩余: $remainingQuota)');
    }

    return result;
  }
}
