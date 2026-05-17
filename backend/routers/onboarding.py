"""
初始配置（闯关）相关接口
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from database import get_database
from bson import ObjectId
from datetime import datetime
from ai_service import ai_service

router = APIRouter()

# 第一关：相遇
class Level1Data(BaseModel):
    smell: str  # 空气的味道
    first_words: str  # 第一句话
    metaphor: str  # 比喻

# 第二关：记忆
class Level2Data(BaseModel):
    photo_url: Optional[str] = None  # 照片URL（如果上传）
    color: str  # 穿的颜色
    conversation: str  # 当时的对话
    song: str  # 背景音乐

# 第三关：期许
class Level3Data(BaseModel):
    one_year: str  # 1年后
    three_years: str  # 3年后
    ten_years: str  # 10年后

# 第四关：相爱总会有阴天
class Level4Data(BaseModel):
    action: str  # 希望对方做的事
    magic_words: str  # 让情绪软下来的话
    ritual: str  # 和好仪式
    forgiveness: str  # 提前原谅的话

class OnboardingData(BaseModel):
    user_id: str
    level1: Optional[Level1Data] = None
    level2: Optional[Level2Data] = None
    level3: Optional[Level3Data] = None
    level4: Optional[Level4Data] = None

@router.post("/save")
async def save_onboarding_data(data: OnboardingData):
    """保存初始配置数据"""
    db = get_database()
    
    # 准备保存的数据
    onboarding_dict = {
        "user_id": data.user_id,
        "level1": data.level1.dict() if data.level1 else None,
        "level2": data.level2.dict() if data.level2 else None,
        "level3": data.level3.dict() if data.level3 else None,
        "level4": data.level4.dict() if data.level4 else None,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    
    # 检查是否已存在
    existing = await db.onboarding.find_one({"user_id": data.user_id})
    
    if existing:
        # 更新
        await db.onboarding.update_one(
            {"user_id": data.user_id},
            {"$set": onboarding_dict}
        )
    else:
        # 插入
        await db.onboarding.insert_one(onboarding_dict)
    
    return {
        "success": True,
        "message": "数据已保存"
    }

@router.get("/data/{user_id}")
async def get_onboarding_data(user_id: str):
    """获取初始配置数据"""
    db = get_database()
    
    data = await db.onboarding.find_one({"user_id": user_id})
    
    if not data:
        return {
            "success": True,
            "data": None
        }
    
    # 转换ObjectId为字符串
    data["_id"] = str(data["_id"])
    
    return {
        "success": True,
        "data": data
    }

@router.post("/level1/blessing")
async def generate_level1_blessing(data: Level1Data):
    """生成第一关的AI祝福"""
    try:
        # 构建prompt
        prompt = f"""用户刚刚分享了他们相遇的故事：
- 空气的味道：{data.smell}
- 第一句话：{data.first_words}
- 相遇的比喻：{data.metaphor}

请以一个可爱的爱情AI助手（名字叫Cupid）的身份，给他们一段温暖的祝福。
要求：
1. 50-80字
2. 语气可爱、温柔
3. 要提到他们分享的细节
4. 用emoji增加可爱感
5. 结尾要有鼓励和祝福"""

        # 调用AI生成
        blessing = await ai_service.generate_reply(
            content=prompt,
            emotion_tag="温暖",
            title="第一关祝福"
        )
        
        return {
            "success": True,
            "blessing": blessing
        }
    except Exception as e:
        # 备用祝福
        return {
            "success": True,
            "blessing": "你看，开始的时候连空气都是有形状的。保存这些瞬间的人，一定很珍惜对方。💕 —— Cupid"
        }

@router.post("/level4/save-forgiveness")
async def save_forgiveness_message(user_id: str, partner_id: str, message: str):
    """保存第四关的原谅留言（将来吵架时使用）"""
    db = get_database()
    
    forgiveness_dict = {
        "from_user_id": user_id,
        "to_user_id": partner_id,
        "message": message,
        "used": False,
        "created_at": datetime.utcnow()
    }
    
    result = await db.forgiveness_messages.insert_one(forgiveness_dict)
    
    return {
        "success": True,
        "message": "原谅留言已保存",
        "message_id": str(result.inserted_id)
    }

@router.get("/forgiveness/{user_id}")
async def get_forgiveness_message(user_id: str):
    """获取对方给自己的原谅留言（吵架时使用）"""
    db = get_database()
    
    message = await db.forgiveness_messages.find_one({
        "to_user_id": user_id,
        "used": False
    })
    
    if not message:
        return {
            "success": True,
            "message": None
        }
    
    # 标记为已使用
    await db.forgiveness_messages.update_one(
        {"_id": message["_id"]},
        {"$set": {"used": True, "used_at": datetime.utcnow()}}
    )
    
    return {
        "success": True,
        "message": {
            "text": message["message"],
            "from_user_id": message["from_user_id"],
            "created_at": message["created_at"].isoformat()
        }
    }
