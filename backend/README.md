# 情绪便利贴后端 API

## 快速开始

### 1. 安装依赖

```bash
pip install -r requirements.txt
```

**完整依赖列表：**
```
fastapi==0.109.0
uvicorn[standard]==0.27.0
motor==3.3.2
pymongo==4.6.1
pydantic==2.5.3
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
python-dotenv==1.0.0
```

### 2. 配置环境变量

复制 `.env.example` 为 `.env` 并修改配置：

```bash
cp .env.example .env
```

### 3. 启动MongoDB

```bash
# Windows
net start MongoDB

# 或手动启动
mongod --dbpath "C:\data\db"
```

### 4. 运行服务器

```bash
python main.py
```

或使用uvicorn：
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## API文档

启动服务器后访问：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API接口列表

### 认证接口 (/api/auth)

#### POST /api/auth/register
注册新用户

**请求体：**
```json
{
  "username": "user1",
  "password": "123456"
}
```

**响应：**
```json
{
  "success": true,
  "message": "注册成功",
  "userId": "507f1f77bcf86cd799439011",
  "username": "user1",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

#### POST /api/auth/login
用户登录

**请求体：**
```json
{
  "username": "user1",
  "password": "123456"
}
```

**响应：**
```json
{
  "success": true,
  "message": "登录成功",
  "userId": "507f1f77bcf86cd799439011",
  "username": "user1",
  "partnerId": null,
  "isPartnerBound": false,
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### 用户接口 (/api/user)

#### POST /api/user/bind-request
发送情侣绑定请求

**请求体：**
```json
{
  "userId": "507f1f77bcf86cd799439011",
  "partnerUsername": "user2"
}
```

#### POST /api/user/accept-bind
接受绑定请求

**请求体：**
```json
{
  "requestId": "507f1f77bcf86cd799439012"
}
```

#### GET /api/user/bind-requests/{user_id}
获取待处理的绑定请求

### 便利贴接口 (/api/notes)

#### POST /api/notes/
创建便利贴

**请求体：**
```json
{
  "title": "今天有点不开心",
  "content": "工作上遇到了一些问题...",
  "emotion_tag": "难过"
}
```

**查询参数：**
- `user_id`: 用户ID

#### GET /api/notes/
获取便利贴列表

**查询参数：**
- `user_id`: 用户ID
- `skip`: 跳过数量（分页）
- `limit`: 返回数量（默认50）

#### GET /api/notes/{note_id}
获取单个便利贴

#### PUT /api/notes/{note_id}
更新便利贴状态

**查询参数：**
- `status`: active | resolved | deleted

#### DELETE /api/notes/{note_id}
删除便利贴（软删除）

## 数据库结构

### users 集合
```javascript
{
  "_id": ObjectId,
  "username": String,
  "password_hash": String,
  "partner_id": String | null,
  "is_partner_bound": Boolean,
  "onboarding_completed": Boolean,
  "created_at": DateTime
}
```

### bind_requests 集合
```javascript
{
  "_id": ObjectId,
  "from_user_id": String,
  "from_username": String,
  "to_username": String,
  "status": "pending" | "accepted" | "rejected",
  "created_at": DateTime
}
```

### notes 集合
```javascript
{
  "_id": ObjectId,
  "user_id": String,
  "title": String | null,
  "content": String,
  "emotion_tag": String,
  "ai_reply": String | null,
  "status": "active" | "resolved" | "deleted",
  "created_at": DateTime,
  "updated_at": DateTime
}
```

## 测试命令

### 使用curl测试

**注册：**
```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test1","password":"123456"}'
```

**登录：**
```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test1","password":"123456"}'
```

**创建便利贴：**
```bash
curl -X POST "http://localhost:8000/api/notes/?user_id=YOUR_USER_ID" \
  -H "Content-Type: application/json" \
  -d '{"title":"测试","content":"这是测试内容","emotion_tag":"生气"}'
```

## 部署到香港服务器

### 1. 上传代码
```bash
scp -r backend/ user@your-server-ip:/path/to/app/
```

### 2. 安装依赖
```bash
ssh user@your-server-ip
cd /path/to/app/backend
pip install -r requirements.txt
```

### 3. 配置Nginx反向代理

创建 `/etc/nginx/sites-available/emotion-notes`：
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### 4. 使用systemd管理服务

创建 `/etc/systemd/system/emotion-notes.service`：
```ini
[Unit]
Description=Emotion Notes API
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/path/to/app/backend
Environment="PATH=/usr/local/bin"
ExecStart=/usr/bin/python3 main.py
Restart=always

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl enable emotion-notes
sudo systemctl start emotion-notes
sudo systemctl status emotion-notes
```

## 注意事项

1. 生产环境请修改 `.env` 中的 `SECRET_KEY`
2. 配置CORS允许的域名（在 `main.py` 中）
3. 使用HTTPS（配置SSL证书）
4. 定期备份MongoDB数据
5. 监控服务器日志和性能

## TODO

- [ ] 集成OpenAI API生成AI回复
- [ ] 添加用户头像上传
- [ ] 实现便利贴分享功能
- [ ] 添加情绪统计分析
- [ ] 实现双人协作模式
