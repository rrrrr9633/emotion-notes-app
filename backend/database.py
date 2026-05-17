from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.server_api import ServerApi
import os
from dotenv import load_dotenv

load_dotenv()

class Database:
    client: AsyncIOMotorClient = None
    db = None

db = Database()

async def connect_to_mongo():
    """连接到MongoDB"""
    mongodb_url = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
    database_name = os.getenv("DATABASE_NAME", "emotion_notes_db")
    
    print(f"正在连接到MongoDB: {mongodb_url}")
    
    db.client = AsyncIOMotorClient(
        mongodb_url,
        server_api=ServerApi('1')
    )
    db.db = db.client[database_name]
    
    # 测试连接
    try:
        await db.client.admin.command('ping')
        print(f"✅ 成功连接到MongoDB数据库: {database_name}")
    except Exception as e:
        print(f"❌ MongoDB连接失败: {e}")
        raise

async def close_mongo_connection():
    """关闭MongoDB连接"""
    if db.client:
        db.client.close()
        print("MongoDB连接已关闭")

def get_database():
    """获取数据库实例"""
    return db.db
