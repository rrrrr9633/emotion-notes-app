"""
数据库初始化脚本
创建必要的索引，确保数据完整性和查询性能
"""
from database import get_database
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
MONGO_URI = "mongodb://localhost:27017/"
DB_NAME = "emotion_notes"  # 你的数据库名

# 创建连接
client = AsyncIOMotorClient(MONGO_URI)
db = client[DB_NAME]

async def init_database():
    """初始化数据库索引"""
    db = get_database()
    
    print("开始初始化数据库索引...")
    
    # 用户集合索引
    print("创建 users 集合索引...")
    await db.users.create_index("username", unique=True)
    await db.users.create_index("partner_id")
    print("✓ users 集合索引创建完成")
    
    # 游戏存档集合索引 - 确保每个用户只有一条存档
    print("创建 game_archives 集合索引...")
    await db.game_archives.create_index("user_id", unique=True)
    await db.game_archives.create_index("partner_id")
    await db.game_archives.create_index("created_at")
    await db.game_archives.create_index("all_completed_at")
    print("✓ game_archives 集合索引创建完成")
    
    # 绑定请求集合索引
    print("创建 bind_requests 集合索引...")
    await db.bind_requests.create_index("from_user_id")
    await db.bind_requests.create_index("to_username")
    await db.bind_requests.create_index("status")
    await db.bind_requests.create_index("created_at")
    print("✓ bind_requests 集合索引创建完成")
    
    # 便利贴集合索引
    print("创建 notes 集合索引...")
    await db.notes.create_index("user_id")
    await db.notes.create_index("status")
    await db.notes.create_index("created_at")
    await db.notes.create_index([("user_id", 1), ("created_at", -1)])
    print("✓ notes 集合索引创建完成")
    
    print("\n数据库初始化完成！")
    print("=" * 50)
    print("索引说明：")
    print("1. users.username - 唯一索引，确保用户名不重复")
    print("2. game_archives.user_id - 唯一索引，确保每个用户只有一条游戏存档")
    print("3. 其他索引用于提升查询性能")
    print("=" * 50)

if __name__ == "__main__":
    asyncio.run(init_database())
