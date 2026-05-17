from fastapi import APIRouter, HTTPException, status, UploadFile, File
from pydantic import BaseModel
from database import get_database
from bson import ObjectId
from datetime import datetime
from ai_service import ai_service
from models_game import Level1Submit, Level2Submit, Level3Submit, Level4Submit, GameArchive
import os
import uuid

router = APIRouter()

class Level1Data(BaseModel):
    smell: str
    first_words: str
    metaphor: str

class Level2Data(BaseModel):
    color: str
    dialogue: str
    song: str
    photo_url: str

@router.get("/progress/{user_id}")
async def get_game_progress(user_id: str):
    """获取用户游戏进度"""
    db = get_database()
    
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    return {
        "success": True,
        "onboarding_completed": user.get("onboarding_completed", False),
        "current_level": user.get("current_level", 0)
    }

@router.post("/complete/{user_id}")
async def complete_game(user_id: str):
    """完成游戏"""
    db = get_database()
    
    result = await db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {
            "onboarding_completed": True,
            "current_level": 4,
            "completed_at": datetime.utcnow()
        }}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    return {
        "success": True,
        "message": "游戏完成"
    }

@router.post("/update-level/{user_id}")
async def update_level(user_id: str, level: int):
    """更新当前关卡"""
    db = get_database()
    
    result = await db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"current_level": level}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    return {
        "success": True,
        "message": "关卡更新成功"
    }

@router.post("/level1/blessing")
async def get_level1_blessing(data: Level1Data):
    """
    获取第一关AI祝福
    使用ai_service中的AURA生成祝福
    """
    try:
        # 调用AI服务生成祝福
        blessing = await ai_service.generate_level1_blessing(
            smell=data.smell,
            first_words=data.first_words,
            metaphor=data.metaphor
        )
        
        return {
            "success": True,
            "blessing": blessing,
            "ai_name": "AURA"
        }
                
    except Exception as e:
        print(f"生成祝福失败: {e}")
        # 出错时返回默认祝福
        return {
            "success": True,
            "blessing": f"亲爱的，你们的相遇充满了美好与浪漫。愿你们的爱情像初雪一样纯净，像星光一样永恒。每一个瞬间都值得珍藏，每一份感动都值得铭记。💕✨",
            "ai_name": "AURA"
        }

@router.post("/level2/upload-photo")
async def upload_photo(photo: UploadFile = File(...)):
    """上传第二关照片"""
    try:
        # 创建上传目录
        upload_dir = "uploads/photos"
        os.makedirs(upload_dir, exist_ok=True)
        
        # 生成唯一文件名
        file_extension = os.path.splitext(photo.filename)[1]
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        file_path = os.path.join(upload_dir, unique_filename)
        
        # 保存文件
        with open(file_path, "wb") as f:
            content = await photo.read()
            f.write(content)
        
        # 返回文件URL（这里简化处理，实际应该返回完整的URL）
        photo_url = f"/uploads/photos/{unique_filename}"
        
        return {
            "success": True,
            "photo_url": photo_url,
            "message": "照片上传成功"
        }
    except Exception as e:
        print(f"上传照片失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")

@router.post("/level2/blessing")
async def get_level2_blessing(data: Level2Data):
    """获取第二关AI祝福"""
    try:
        # 调用AI服务生成祝福
        blessing = await ai_service.generate_level2_blessing(
            color=data.color,
            dialogue=data.dialogue,
            song=data.song
        )
        
        # 构建描述
        description = f"那天你穿着{data.color}，你说\"{data.dialogue}\"，我的手机正好循环到《{data.song}》。"
        
        return {
            "success": True,
            "blessing": blessing,
            "description": description,
            "ai_name": "AURA"
        }
    except Exception as e:
        print(f"生成祝福失败: {e}")
        return {
            "success": True,
            "blessing": "照片会褪色，但那天你说话的语气不会。我们已经把它保存在这里了。💕",
            "description": "",
            "ai_name": "AURA"
        }

@router.post("/level3/blessing")
async def get_level3_blessing(data: dict):
    """获取第三关AI祝福"""
    try:
        # 调用AI服务生成祝福
        blessing = await ai_service.generate_level3_blessing(
            node1=data.get('node1', ''),
            node2=data.get('node2', ''),
            node3=data.get('node3', '')
        )
        
        return {
            "success": True,
            "blessing": blessing,
            "ai_name": "AURA"
        }
    except Exception as e:
        print(f"生成祝福失败: {e}")
        return {
            "success": True,
            "blessing": "未来不需要很宏大，有具体的画面就够了。你看，你已经画好了三张草图。💕",
            "ai_name": "AURA"
        }

@router.post("/level4/blessing")
async def get_level4_blessing(data: dict):
    """获取第四关AI祝福"""
    try:
        # 调用AI服务生成祝福
        blessing = await ai_service.generate_level4_blessing(
            action=data.get('action', ''),
            phrase=data.get('phrase', ''),
            ritual=data.get('ritual', ''),
            forgive_message=data.get('forgive_message', '')
        )
        
        return {
            "success": True,
            "blessing": blessing,
            "ai_name": "AURA"
        }
    except Exception as e:
        print(f"生成祝福失败: {e}")
        return {
            "success": True,
            "blessing": "蓝色是深海的颜色——表面有风浪，但深处始终安静。你们提前写下的这些，就是彼此的锚。💙",
            "ai_name": "AURA"
        }


# ========== 游戏数据永久存档API ==========

@router.post("/archive/level1")
async def archive_level1(data: Level1Submit):
    """保存第一关数据到永久存档 - 每个用户独立存储"""
    db = get_database()
    
    try:
        # 验证用户存在
        user = await db.users.find_one({"_id": ObjectId(data.user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 查找该用户的存档（通过user_id唯一标识）
        archive = await db.game_archives.find_one({"user_id": data.user_id})
        
        if archive:
            # 更新现有存档
            result = await db.game_archives.update_one(
                {"user_id": data.user_id},
                {"$set": {
                    "level1_smell": data.smell,
                    "level1_first_words": data.first_words,
                    "level1_metaphor": data.metaphor,
                    "level1_blessing": data.blessing,
                    "level1_completed_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow()
                }}
            )
            print(f"用户 {data.user_id} 的第一关数据已更新")
        else:
            # 创建新存档（该用户的第一条存档）
            new_archive = {
                "user_id": data.user_id,
                "partner_id": user.get("partner_id"),
                "level1_smell": data.smell,
                "level1_first_words": data.first_words,
                "level1_metaphor": data.metaphor,
                "level1_blessing": data.blessing,
                "level1_completed_at": datetime.utcnow(),
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
            await db.game_archives.insert_one(new_archive)
            print(f"用户 {data.user_id} 的游戏存档已创建")
        
        return {"success": True, "message": "第一关数据已保存", "user_id": data.user_id}
    except HTTPException:
        raise
    except Exception as e:
        print(f"保存第一关数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"保存失败: {str(e)}")

@router.post("/archive/level2")
async def archive_level2(data: Level2Submit):
    """保存第二关数据到永久存档 - 每个用户独立存储"""
    db = get_database()
    
    try:
        # 验证用户存在
        user = await db.users.find_one({"_id": ObjectId(data.user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 更新该用户的存档
        result = await db.game_archives.update_one(
            {"user_id": data.user_id},
            {"$set": {
                "level2_color": data.color,
                "level2_dialogue": data.dialogue,
                "level2_song": data.song,
                "level2_photo_url": data.photo_url,
                "level2_blessing": data.blessing,
                "level2_completed_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }},
            upsert=True
        )
        
        print(f"用户 {data.user_id} 的第二关数据已保存")
        return {"success": True, "message": "第二关数据已保存", "user_id": data.user_id}
    except HTTPException:
        raise
    except Exception as e:
        print(f"保存第二关数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"保存失败: {str(e)}")

@router.post("/archive/level3")
async def archive_level3(data: Level3Submit):
    """保存第三关数据到永久存档 - 每个用户独立存储"""
    db = get_database()
    
    try:
        # 验证用户存在
        user = await db.users.find_one({"_id": ObjectId(data.user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 更新该用户的存档
        result = await db.game_archives.update_one(
            {"user_id": data.user_id},
            {"$set": {
                "level3_habit": data.habit,
                "level3_moment": data.moment,
                "level3_future_plan": data.future_plan,
                "level3_blessing": data.blessing,
                "level3_completed_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }},
            upsert=True
        )
        
        print(f"用户 {data.user_id} 的第三关数据已保存")
        return {"success": True, "message": "第三关数据已保存", "user_id": data.user_id}
    except HTTPException:
        raise
    except Exception as e:
        print(f"保存第三关数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"保存失败: {str(e)}")

@router.post("/archive/level4")
async def archive_level4(data: Level4Submit):
    """保存第四关数据到永久存档，并标记所有关卡完成 - 每个用户独立存储"""
    db = get_database()
    
    try:
        # 验证用户存在
        user = await db.users.find_one({"_id": ObjectId(data.user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 更新该用户的存档，标记游戏完成
        result = await db.game_archives.update_one(
            {"user_id": data.user_id},
            {"$set": {
                "level4_action": data.action,
                "level4_phrase": data.phrase,
                "level4_ritual": data.ritual,
                "level4_forgive_message": data.forgive_message,
                "level4_blessing": data.blessing,
                "level4_completed_at": datetime.utcnow(),
                "all_completed_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }},
            upsert=True
        )
        
        # 更新用户的游戏完成状态
        await db.users.update_one(
            {"_id": ObjectId(data.user_id)},
            {"$set": {
                "onboarding_completed": True,
                "current_level": 4
            }}
        )
        
        print(f"用户 {data.user_id} 完成了所有游戏关卡")
        return {"success": True, "message": "第四关数据已保存，游戏全部完成", "user_id": data.user_id}
    except HTTPException:
        raise
    except Exception as e:
        print(f"保存第四关数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"保存失败: {str(e)}")

@router.get("/archive/{user_id}")
async def get_game_archive(user_id: str):
    """获取指定用户的游戏存档 - 数据隔离，只返回该用户的数据"""
    db = get_database()
    
    try:
        # 验证用户存在
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 只查询该用户的存档
        archive = await db.game_archives.find_one({"user_id": user_id})
        
        if not archive:
            return {
                "success": True, 
                "archive": None,
                "message": "该用户还没有游戏存档"
            }
        
        # 转换ObjectId为字符串
        archive["_id"] = str(archive["_id"])
        
        print(f"获取用户 {user_id} 的游戏存档")
        return {"success": True, "archive": archive}
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取存档失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")
