# -*- coding: utf-8 -*-

"""
备考打卡 - 本地后端服务器（SQLite 数据库版）

功能：
1. 用户登录验证（账号密码校验）
2. 提供用户信息（补签额度、打卡项目数据等）
3. 数据存储在 SQLite 数据库中
4. 数据同步接口：上传/下载用户的习惯、打卡记录、补签额度

启动方式：
    python server.py

默认监听：
    地址：0.0.0.0（局域网可访问）
    端口：5678
"""

import json
import os
import sqlite3
import hashlib
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

# 服务器配置
HOST = '0.0.0.0'
PORT = 5678
DB_FILE = os.path.join(os.path.dirname(__file__), 'server.db')


def get_db():
    """获取数据库连接（每次请求创建新连接，线程安全）"""
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row  # 让查询结果支持列名访问
    conn.execute("PRAGMA journal_mode=WAL")  # WAL 模式提升并发性能
    return conn


def init_db():
    """初始化数据库表结构（首次运行自动创建）"""
    conn = get_db()
    cursor = conn.cursor()

    # 用户表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            display_name TEXT NOT NULL DEFAULT '',
            avatar TEXT DEFAULT '',
            makeup_quota_per_month INTEGER DEFAULT 5,
            created_at TEXT DEFAULT (datetime('now', 'localtime'))
        )
    """)

    # 习惯数据表（每个用户独立存储）
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS habits (
            id TEXT NOT NULL,
            username TEXT NOT NULL,
            name TEXT NOT NULL,
            icon TEXT DEFAULT '',
            color INTEGER DEFAULT 0,
            exam_category TEXT DEFAULT '',
            frequency_type TEXT DEFAULT '',
            weekly_count INTEGER DEFAULT 0,
            custom_days TEXT DEFAULT '',
            created_at TEXT DEFAULT '',
            is_active INTEGER DEFAULT 1,
            PRIMARY KEY (id, username)
        )
    """)

    # 打卡记录表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS check_ins (
            id TEXT NOT NULL,
            username TEXT NOT NULL,
            habit_id TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT DEFAULT '',
            image_path TEXT DEFAULT '',
            focus_duration INTEGER DEFAULT 0,
            is_makeup INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now', 'localtime')),
            PRIMARY KEY (id, username)
        )
    """)

    # 补签额度月度记录表（记录每个用户每月的已使用额度）
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS makeup_usage (
            username TEXT NOT NULL,
            year_month TEXT NOT NULL,
            used_count INTEGER DEFAULT 0,
            PRIMARY KEY (username, year_month)
        )
    """)

    # 插入默认用户（如果不存在）
    default_users = [
        ('admin', _hash_password('admin123'), '管理员', 5),
        ('test', _hash_password('test123'), '测试用户', 5),
    ]
    for username, password, display_name, quota in default_users:
        cursor.execute(
            "SELECT id FROM users WHERE username = ?", (username,)
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO users (username, password, display_name, makeup_quota_per_month) VALUES (?, ?, ?, ?)",
                (username, password, display_name, quota)
            )

    conn.commit()
    conn.close()
    print(f"[数据库] 初始化完成: {DB_FILE}")


def _hash_password(password):
    """SHA-256 密码哈希"""
    return hashlib.sha256(password.encode('utf-8')).hexdigest()


class RequestHandler(BaseHTTPRequestHandler):
    """HTTP 请求处理器"""

    def _set_headers(self, status_code=200, content_type='application/json'):
        """设置响应头（允许跨域）"""
        self.send_response(status_code)
        self.send_header('Content-Type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()

    def _send_json(self, data, status_code=200):
        """发送 JSON 响应"""
        self._set_headers(status_code)
        response = json.dumps(data, ensure_ascii=False)
        self.wfile.write(response.encode('utf-8'))

    def _read_body(self):
        """读取请求体"""
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length > 0:
            return self.rfile.read(content_length).decode('utf-8')
        return '{}'

    def _get_token_user(self):
        """从 Authorization 头中解析 token 并返回用户名（None 表示无效）"""
        token = self.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return None

        conn = get_db()
        cursor = conn.cursor()
        # token 格式为 username:password_hash 的哈希
        cursor.execute("SELECT username, password FROM users")
        for row in cursor.fetchall():
            stored_token = _hash_password(f"{row['username']}:{row['password']}")
            if token == stored_token:
                conn.close()
                return row['username']
        conn.close()
        return None

    def do_OPTIONS(self):
        """处理 CORS 预检请求"""
        self._set_headers(204)

    def do_GET(self):
        """处理 GET 请求"""
        parsed = urlparse(self.path)
        path = parsed.path

        # 根路径：返回友好页面
        if path == '/' or path == '':
            self._set_headers(200, 'text/html; charset=utf-8')
            html = '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>笔程 - 服务器运行中</title>
    <style>
        body { font-family: -apple-system, sans-serif; text-align: center; padding: 60px 20px; background: #f5f5f5; }
        .card { background: white; max-width: 500px; margin: 0 auto; padding: 40px; border-radius: 12px; box-shadow: 0 2px 12px rgba(0,0,0,0.08); }
        h1 { color: #6B8E9F; font-size: 24px; margin: 0 0 8px; }
        p { color: #666; font-size: 14px; line-height: 1.6; }
        .status { display: inline-block; background: #e8f5e9; color: #2e7d32; padding: 4px 12px; border-radius: 20px; font-size: 13px; margin: 16px 0; }
        .api-list { text-align: left; background: #f9f9f9; padding: 16px; border-radius: 8px; margin-top: 16px; }
        .api-list code { background: #eee; padding: 2px 6px; border-radius: 4px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>✏️ 笔程</h1>
        <p>服务器运行正常</p>
        <div class="status">● Online</div>
        <div class="api-list">
            <p style="margin:0 0 8px;font-weight:600;font-size:13px;">可用接口：</p>
            <p style="margin:4px 0;"><code>GET /api/health</code> — 健康检查</p>
            <p style="margin:4px 0;"><code>POST /api/login</code> — 用户登录</p>
            <p style="margin:4px 0;"><code>GET /api/user/info</code> — 获取用户信息</p>
            <p style="margin:4px 0;"><code>POST /api/data/sync</code> — 数据同步</p>
        </div>
    </div>
</body>
</html>'''
            self.wfile.write(html.encode('utf-8'))
            return

        if path == '/api/health':
            # 健康检查接口
            self._send_json({
                'code': 0,
                'message': '服务器运行正常',
                'data': {
                    'serverName': '备考打卡服务器',
                    'version': '2.0.0',
                    'time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
            })

        elif path == '/api/user/info':
            # 获取用户信息（需要 token 验证）
            username = self._get_token_user()
            if username is None:
                self._send_json({'code': 401, 'message': '未登录'}, 401)
                return

            conn = get_db()
            cursor = conn.cursor()
            cursor.execute(
                "SELECT username, display_name, avatar, makeup_quota_per_month FROM users WHERE username = ?",
                (username,)
            )
            user = cursor.fetchone()
            conn.close()

            if user:
                self._send_json({
                    'code': 0,
                    'message': 'ok',
                    'data': {
                        'username': user['username'],
                        'displayName': user['display_name'],
                        'avatar': user['avatar'] or '',
                        'makeupQuotaPerMonth': user['makeup_quota_per_month'],
                    }
                })
            else:
                self._send_json({'code': 404, 'message': '用户不存在'}, 404)

        else:
            self._send_json({'code': 404, 'message': '接口不存在'}, 404)

    def do_POST(self):
        """处理 POST 请求"""
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/login':
            # 用户登录接口
            try:
                body = json.loads(self._read_body())
            except json.JSONDecodeError:
                self._send_json({'code': 400, 'message': '请求格式错误'}, 400)
                return

            username = body.get('username', '').strip()
            password = body.get('password', '')

            if not username or not password:
                self._send_json({'code': 400, 'message': '用户名和密码不能为空'}, 400)
                return

            conn = get_db()
            cursor = conn.cursor()
            cursor.execute(
                "SELECT username, password, display_name, avatar, makeup_quota_per_month FROM users WHERE username = ?",
                (username,)
            )
            user = cursor.fetchone()
            conn.close()

            if user and user['password'] == _hash_password(password):
                token = _hash_password(f"{username}:{user['password']}")
                self._send_json({
                    'code': 0,
                    'message': '登录成功',
                    'data': {
                        'token': token,
                        'username': user['username'],
                        'displayName': user['display_name'],
                        'avatar': user['avatar'] or '',
                        'makeupQuotaPerMonth': user['makeup_quota_per_month'],
                    }
                })
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 用户 [{username}] 登录成功")
            else:
                self._send_json({'code': 401, 'message': '用户名或密码错误'}, 401)
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 用户 [{username}] 登录失败：账号或密码错误")

        elif path == '/api/data/sync':
            # 数据同步：上传或下载用户的习惯、打卡记录、补签额度
            username = self._get_token_user()
            if username is None:
                self._send_json({'code': 401, 'message': '未登录'}, 401)
                return

            try:
                body = json.loads(self._read_body())
                # === 有请求体 => 上传数据 ===
                conn = get_db()
                cursor = conn.cursor()

                # 上传习惯
                habits = body.get('habits', [])
                if habits:
                    # 删除该用户的所有旧习惯，替换为新数据
                    cursor.execute("DELETE FROM habits WHERE username = ?", (username,))
                    for h in habits:
                        cursor.execute(
                            """INSERT OR REPLACE INTO habits
                            (id, username, name, icon, color, exam_category, frequency_type,
                             weekly_count, custom_days, created_at, is_active)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                            (
                                h.get('id', ''),
                                username,
                                h.get('name', ''),
                                h.get('icon', ''),
                                h.get('color', 0),
                                h.get('examCategory', ''),
                                h.get('frequencyType', ''),
                                h.get('weeklyCount', 0),
                                json.dumps(h.get('customDays', [])),
                                h.get('createdAt', ''),
                                1 if h.get('isActive', True) else 0,
                            )
                        )

                # 上传打卡记录
                check_ins = body.get('checkIns', [])
                if check_ins:
                    cursor.execute("DELETE FROM check_ins WHERE username = ?", (username,))
                    for c in check_ins:
                        cursor.execute(
                            """INSERT OR REPLACE INTO check_ins
                            (id, username, habit_id, date, note, image_path,
                             focus_duration, is_makeup, created_at)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                            (
                                c.get('id', ''),
                                username,
                                c.get('habitId', ''),
                                c.get('date', ''),
                                c.get('note', ''),
                                c.get('imagePath', ''),
                                c.get('focusDuration', 0),
                                1 if c.get('isMakeup', False) else 0,
                                c.get('createdAt', ''),
                            )
                        )

                # 上传补签额度使用情况
                makeup_quota = body.get('makeupQuota')
                if makeup_quota is not None:
                    now = datetime.now()
                    year_month = f"{now.year}_{now.month}"
                    remaining = makeup_quota
                    # 查询该用户该月的总额度
                    cursor.execute(
                        "SELECT makeup_quota_per_month FROM users WHERE username = ?",
                        (username,)
                    )
                    user_row = cursor.fetchone()
                    total_quota = user_row['makeup_quota_per_month'] if user_row else 5
                    used_count = total_quota - remaining
                    cursor.execute(
                        """INSERT OR REPLACE INTO makeup_usage (username, year_month, used_count)
                        VALUES (?, ?, ?)""",
                        (username, year_month, max(0, used_count))
                    )

                conn.commit()
                conn.close()

                print(
                    f"[{datetime.now().strftime('%H:%M:%S')}] 用户 [{username}] "
                    f"上传了 {len(habits)} 个习惯、{len(check_ins)} 条打卡记录"
                )
                self._send_json({'code': 0, 'message': '同步成功'})

            except json.JSONDecodeError:
                # === 无请求体或格式错误 => 下载数据 ===
                conn = get_db()
                cursor = conn.cursor()

                # 下载习惯
                cursor.execute(
                    "SELECT * FROM habits WHERE username = ?", (username,)
                )
                habits = []
                for row in cursor.fetchall():
                    habits.append({
                        'id': row['id'],
                        'name': row['name'],
                        'icon': row['icon'],
                        'color': row['color'],
                        'examCategory': row['exam_category'],
                        'frequencyType': row['frequency_type'],
                        'weeklyCount': row['weekly_count'],
                        'customDays': json.loads(row['custom_days']) if row['custom_days'] else [],
                        'createdAt': row['created_at'],
                        'isActive': bool(row['is_active']),
                    })

                # 下载打卡记录
                cursor.execute(
                    "SELECT * FROM check_ins WHERE username = ?", (username,)
                )
                check_ins = []
                for row in cursor.fetchall():
                    check_ins.append({
                        'id': row['id'],
                        'habitId': row['habit_id'],
                        'date': row['date'],
                        'note': row['note'],
                        'imagePath': row['image_path'],
                        'focusDuration': row['focus_duration'],
                        'isMakeup': bool(row['is_makeup']),
                        'createdAt': row['created_at'],
                    })

                # 下载补签额度
                now = datetime.now()
                year_month = f"{now.year}_{now.month}"
                cursor.execute(
                    "SELECT makeup_quota_per_month FROM users WHERE username = ?",
                    (username,)
                )
                user_row = cursor.fetchone()
                total_quota = user_row['makeup_quota_per_month'] if user_row else 5

                cursor.execute(
                    "SELECT used_count FROM makeup_usage WHERE username = ? AND year_month = ?",
                    (username, year_month)
                )
                usage_row = cursor.fetchone()
                used_count = usage_row['used_count'] if usage_row else 0
                remaining_quota = total_quota - used_count

                conn.close()

                self._send_json({
                    'code': 0,
                    'message': 'ok',
                    'data': {
                        'habits': habits,
                        'checkIns': check_ins,
                        'makeupQuota': remaining_quota,
                        'updatedAt': datetime.now().isoformat(),
                    }
                })
                print(
                    f"[{datetime.now().strftime('%H:%M:%S')}] 用户 [{username}] "
                    f"下载了 {len(habits)} 个习惯、{len(check_ins)} 条打卡记录"
                )

        else:
            self._send_json({'code': 404, 'message': '接口不存在'}, 404)

    def log_message(self, format, *args):
        """自定义日志格式"""
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]} {args[1]} {args[2]}")


def main():
    """启动服务器"""
    # 初始化数据库
    init_db()

    print("=" * 50)
    print("  笔程 - Local Server v2.0")
    print("  [Database: SQLite]")
    print("=" * 50)
    print(f"  Listen: http://{HOST}:{PORT}")
    print(f"  DB:     {DB_FILE}")
    print(f"  Time:   {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("-" * 50)
    print("  Available APIs:")
    print(f"    GET  /api/health      - Health check")
    print(f"    POST /api/login       - User login")
    print(f"    GET  /api/user/info   - Get user info")
    print(f"    POST /api/data/sync   - Data sync (upload/download)")
    print("-" * 50)
    print("  Default accounts: admin / admin123")
    print("  Default accounts: test  / test123")
    print("=" * 50)
    print()

    server = HTTPServer((HOST, PORT), RequestHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[提示] 收到中断信号，服务器正在关闭...")
        server.server_close()
        print("[提示] 服务器已关闭")


if __name__ == '__main__':
    main()
