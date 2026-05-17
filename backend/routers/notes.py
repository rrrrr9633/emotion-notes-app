from fastapi import APIRouter, HTTPException, UploadFile, File, Query
from database import get_database
from models import NoteCreate, NoteUpdate, Note, Achievement
from bson import ObjectId
from datetime import datetime, timedelta
from ai_service import ai_service
from typing import Optional
from pydantic import BaseModel
import os
import uuid

router = APIRouter()

class CommentData(BaseModel):
    content: str

@router.post("/create")
async def create_note(note_data: NoteCreate, user_id: str):
    """创建新便利贴并生成AI回复"""
    db = get_database()
    
    try:
        # 验证用户存在
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 生成AI暖心回复
        ai_reply = await ai_service.generate_note_reply(
            content=note_data.content,
            emotion_tag=note_data.emotion_tag
        )
        
        # 创建便利贴
        new_note = {
            "user_id": user_id,
            "title": note_data.title,
            "content": note_data.content,
            "emotion_tag": note_data.emotion_tag,
            "audio_url": note_data.audio_url,
            "ai_reply": ai_reply,
            "is_resolved": False,
            "status": "active",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        result = await db.notes.insert_one(new_note)
        new_note["_id"] = str(result.inserted_id)
        
        print(f"用户 {user_id} 创建了新便利贴")
        return {
            "success": True,
            "note": new_note,
            "message": "便利贴创建成功"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"创建便利贴失败: {e}")
        raise HTTPException(status_code=500, detail=f"创建失败: {str(e)}")

@router.post("/upload-audio")
async def upload_audio(audio: UploadFile = File(...)):
    """上传语音便利贴"""
    try:
        # 创建上传目录
        upload_dir = "uploads/audio"
        os.makedirs(upload_dir, exist_ok=True)
        
        # 生成唯一文件名
        file_extension = os.path.splitext(audio.filename)[1]
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        file_path = os.path.join(upload_dir, unique_filename)
        
        # 保存文件
        with open(file_path, "wb") as f:
            content = await audio.read()
            f.write(content)
        
        audio_url = f"/uploads/audio/{unique_filename}"
        
        return {
            "success": True,
            "audio_url": audio_url,
            "message": "语音上传成功"
        }
    except Exception as e:
        print(f"上传语音失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")

@router.get("/list/{user_id}")
async def get_notes_list(
    user_id: str,
    year: Optional[int] = None,
    month: Optional[int] = None,
    status: Optional[str] = "active"
):
    """获取用户和伴侣的便利贴列表（双方共享）"""
    db = get_database()
    
    try:
        # 验证用户存在
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 构建查询条件 - 包括自己和伴侣的便利贴
        user_ids = [user_id]
        if user.get('partner_id'):
            user_ids.append(user.get('partner_id'))
        
        query = {
            "user_id": {"$in": user_ids},
            "status": status
        }
        
        # 按月份筛选
        if year and month:
            start_date = datetime(year, month, 1)
            if month == 12:
                end_date = datetime(year + 1, 1, 1)
            else:
                end_date = datetime(year, month + 1, 1)
            
            query["created_at"] = {
                "$gte": start_date,
                "$lt": end_date
            }
        
        # 查询便利贴
        notes = await db.notes.find(query).sort("created_at", -1).to_list(length=100)
        
        # 转换ObjectId为字符串
        for note in notes:
            note["_id"] = str(note["_id"])
            note["created_at"] = note["created_at"].isoformat()
            note["updated_at"] = note["updated_at"].isoformat()
            
            # 添加作者信息
            author = await db.users.find_one({"_id": ObjectId(note["user_id"])})
            if author:
                note["author_name"] = author.get("nickname") or author.get("username")
                note["author_avatar"] = author.get("avatar_url")
                note["is_mine"] = note["user_id"] == user_id
        
        return {
            "success": True,
            "notes": notes
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取便利贴列表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 构建查询条件
        query = {"user_id": user_id}
        
        if status:
            query["status"] = status
        
        # 按月份筛选
        if year and month:
            start_date = datetime(year, month, 1)
            if month == 12:
                end_date = datetime(year + 1, 1, 1)
            else:
                end_date = datetime(year, month + 1, 1)
            
            query["created_at"] = {
                "$gte": start_date,
                "$lt": end_date
            }
        
        # 查询便利贴
        notes_cursor = db.notes.find(query).sort("created_at", -1)
        notes = await notes_cursor.to_list(length=100)
        
        # 转换ObjectId
        for note in notes:
            note["_id"] = str(note["_id"])
        
        return {
            "success": True,
            "notes": notes,
            "count": len(notes)
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取便利贴列表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")

@router.get("/detail/{note_id}")
async def get_note_detail(note_id: str, user_id: str):
    """获取便利贴详情"""
    db = get_database()
    
    try:
        # 验证用户
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 获取便利贴
        note = await db.notes.find_one({"_id": ObjectId(note_id)})
        if not note:
            raise HTTPException(status_code=404, detail="便利贴不存在")
        
        # 检查权限（只有作者和伴侣可以查看）
        partner_id = user.get('partner_id')
        if note['user_id'] != user_id and note['user_id'] != partner_id:
            raise HTTPException(status_code=403, detail="无权查看")
        
        # 转换数据
        note['_id'] = str(note['_id'])
        note['created_at'] = note['created_at'].isoformat()
        note['updated_at'] = note['updated_at'].isoformat()
        
        # 添加作者信息
        author = await db.users.find_one({"_id": ObjectId(note['user_id'])})
        if author:
            note['author_name'] = author.get('nickname') or author.get('username')
            note['author_avatar'] = author.get('avatar_url')
            note['is_mine'] = note['user_id'] == user_id
        
        return {
            "success": True,
            "note": note
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取便利贴详情失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/comment/{note_id}")
async def add_comment(note_id: str, comment_data: CommentData, user_id: str = Query(...)):
    """添加留言"""
    db = get_database()
    
    try:
        # 验证便利贴存在
        note = await db.notes.find_one({"_id": ObjectId(note_id)})
        if not note:
            raise HTTPException(status_code=404, detail="便利贴不存在")
        
        # 验证用户权限
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        partner_id = user.get('partner_id')
        if note['user_id'] != user_id and note['user_id'] != partner_id:
            raise HTTPException(status_code=403, detail="无权留言")
        
        # 创建留言
        comment = {
            "note_id": note_id,
            "user_id": user_id,
            "content": comment_data.content,
            "created_at": datetime.utcnow()
        }
        
        result = await db.note_comments.insert_one(comment)
        comment['_id'] = str(result.inserted_id)
        comment['created_at'] = comment['created_at'].isoformat()
        
        # 添加用户信息
        comment['user_name'] = user.get('nickname') or user.get('username')
        comment['user_avatar'] = user.get('avatar_url')
        
        return {
            "success": True,
            "comment": comment,
            "message": "留言成功"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"添加留言失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/comments/{note_id}")
async def get_comments(note_id: str, user_id: str):
    """获取便利贴的留言列表"""
    db = get_database()
    
    try:
        # 验证便利贴存在
        note = await db.notes.find_one({"_id": ObjectId(note_id)})
        if not note:
            raise HTTPException(status_code=404, detail="便利贴不存在")
        
        # 验证用户权限
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        partner_id = user.get('partner_id')
        if note['user_id'] != user_id and note['user_id'] != partner_id:
            raise HTTPException(status_code=403, detail="无权查看")
        
        # 获取留言列表
        comments = await db.note_comments.find({"note_id": note_id}).sort("created_at", 1).to_list(length=100)
        
        # 添加用户信息
        for comment in comments:
            comment['_id'] = str(comment['_id'])
            comment['created_at'] = comment['created_at'].isoformat()
            
            comment_user = await db.users.find_one({"_id": ObjectId(comment['user_id'])})
            if comment_user:
                comment['user_name'] = comment_user.get('nickname') or comment_user.get('username')
                comment['user_avatar'] = comment_user.get('avatar_url')
        
        return {
            "success": True,
            "comments": comments
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取留言失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/request-delete/{note_id}")
async def request_delete_note(note_id: str, user_id: str):
    """请求删除便利贴（需要双方同意）"""
    db = get_database()
    
    try:
        # 获取便利贴
        note = await db.notes.find_one({"_id": ObjectId(note_id)})
        if not note:
            raise HTTPException(status_code=404, detail="便利贴不存在")
        
        # 获取用户信息
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user or not user.get('partner_id'):
            raise HTTPException(status_code=400, detail="未绑定伴侣")
        
        # 检查是否已有删除请求
        existing = await db.delete_requests.find_one({
            "note_id": note_id,
            "status": "pending"
        })
        
        if existing:
            raise HTTPException(status_code=400, detail="已有待处理的删除请求")
        
        # 创建删除请求
        delete_request = {
            "note_id": note_id,
            "requester_id": user_id,
            "requester_name": user.get('nickname') or user.get('username'),
            "created_at": datetime.utcnow(),
            "status": "pending"
        }
        
        await db.delete_requests.insert_one(delete_request)
        
        return {
            "success": True,
            "message": "删除请求已发送，等待对方同意"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"请求删除失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/approve-delete/{note_id}")
async def approve_delete_note(note_id: str, user_id: str):
    """同意删除便利贴"""
    db = get_database()
    
    try:
        # 查找删除请求
        delete_request = await db.delete_requests.find_one({
            "note_id": note_id,
            "status": "pending"
        })
        
        if not delete_request:
            raise HTTPException(status_code=404, detail="删除请求不存在")
        
        # 更新请求状态
        await db.delete_requests.update_one(
            {"_id": delete_request["_id"]},
            {"$set": {"status": "approved"}}
        )
        
        # 删除便利贴
        await db.notes.delete_one({"_id": ObjectId(note_id)})
        
        # 删除相关留言
        await db.note_comments.delete_many({"note_id": note_id})
        
        return {
            "success": True,
            "message": "便利贴已删除"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"同意删除失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/delete-requests/{user_id}")
async def get_delete_requests(user_id: str):
    """获取待处理的删除请求"""
    db = get_database()
    
    try:
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        partner_id = user.get('partner_id')
        if not partner_id:
            return {"success": True, "requests": []}
        
        # 查找对方发起的删除请求
        requests = await db.delete_requests.find({
            "requester_id": partner_id,
            "status": "pending"
        }).to_list(length=100)
        
        for req in requests:
            req['_id'] = str(req['_id'])
            req['created_at'] = req['created_at'].isoformat()
            
            # 获取便利贴信息
            note = await db.notes.find_one({"_id": ObjectId(req['note_id'])})
            if note:
                req['note_content'] = note.get('content', '')[:50] + '...'
        
        return {
            "success": True,
            "requests": requests
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取删除请求失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))
async def get_note_detail(note_id: str, user_id: str):
    """获取便利贴详情"""
    db = get_database()
    
    try:
        note = await db.notes.find_one({
            "_id": ObjectId(note_id),
            "user_id": user_id
        })
        
        if not note:
            raise HTTPException(status_code=404, detail="便利贴不存在")
        
        note["_id"] = str(note["_id"])
        
        return {
            "success": True,
            "note": note
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取便利贴详情失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")

@router.patch("/resolve/{note_id}")
async def mark_note_resolved(note_id: str, user_id: str):
    """标记便利贴为"已消气"状态"""
    db = get_database()
    
    try:
        # 更新便利贴状态
        result = await db.notes.update_one(
            {
                "_id": ObjectId(note_id),
                "user_id": user_id
            },
            {
                "$set": {
                    "is_resolved": True,
                    "resolved_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="便利贴不存在")
        
        # 更新成就系统
        achievement = await db.achievements.find_one({"user_id": user_id})
        
        if achievement:
            new_total = achievement["total_resolved"] + 1
            
            # 宠物等级系统：每10个消气升1级，100级后重生
            # 计算当前周期（每1000个消气为一个周期，对应100级）
            cycle_progress = new_total % 1000  # 当前周期内的进度（0-999）
            new_level = (cycle_progress // 10) + 1  # 等级1-100
            
            # 计算宠物阶段（每个周期内）
            pet_stages = ["egg", "baby", "child", "teen", "adult"]
            # egg: 1-10级, baby: 11-30级, child: 31-50级, teen: 51-80级, adult: 81-100级
            if new_level <= 10:
                new_pet_stage = "egg"
            elif new_level <= 30:
                new_pet_stage = "baby"
            elif new_level <= 50:
                new_pet_stage = "child"
            elif new_level <= 80:
                new_pet_stage = "teen"
            else:
                new_pet_stage = "adult"
            
            # 检查是否重生（达到1000的倍数）
            is_reborn = (new_total % 1000 == 0) and new_total > 0
            
            await db.achievements.update_one(
                {"user_id": user_id},
                {
                    "$set": {
                        "total_resolved": new_total,
                        "current_level": new_level,
                        "pet_stage": new_pet_stage,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            
            level_up = new_level > achievement["current_level"] or is_reborn
        else:
            # 创建成就记录
            user = await db.users.find_one({"_id": ObjectId(user_id)})
            await db.achievements.insert_one({
                "user_id": user_id,
                "partner_id": user.get("partner_id"),
                "total_resolved": 1,
                "current_level": 1,
                "pet_stage": "egg",
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            })
            level_up = False
        
        return {
            "success": True,
            "message": "已标记为消气",
            "level_up": level_up
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"标记消气失败: {e}")
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")

@router.patch("/archive/{note_id}")
async def archive_note(note_id: str, user_id: str):
    """归档便利贴（收入袋子）"""
    db = get_database()
    
    try:
        result = await db.notes.update_one(
            {
                "_id": ObjectId(note_id),
                "user_id": user_id
            },
            {
                "$set": {
                    "status": "archived",
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="便利贴不存在")
        
        return {
            "success": True,
            "message": "便利贴已归档"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"归档便利贴失败: {e}")
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")

@router.delete("/delete/{note_id}")
async def delete_note(note_id: str, user_id: str):
    """删除便利贴"""
    db = get_database()
    
    try:
        result = await db.notes.update_one(
            {
                "_id": ObjectId(note_id),
                "user_id": user_id
            },
            {
                "$set": {
                    "status": "deleted",
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="便利贴不存在")
        
        return {
            "success": True,
            "message": "便利贴已删除"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"删除便利贴失败: {e}")
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")

@router.get("/statistics/{user_id}")
async def get_statistics(user_id: str, days: int = 7):
    """获取情绪统计数据"""
    db = get_database()
    
    try:
        # 验证用户存在
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 计算时间范围
        start_date = datetime.utcnow() - timedelta(days=days)
        
        # 查询该时间段的便利贴
        notes_cursor = db.notes.find({
            "user_id": user_id,
            "status": {"$ne": "deleted"},
            "created_at": {"$gte": start_date}
        })
        notes = await notes_cursor.to_list(length=1000)
        
        # 统计情绪标签
        emotion_counts = {}
        for note in notes:
            emotion = note.get("emotion_tag", "未知")
            emotion_counts[emotion] = emotion_counts.get(emotion, 0) + 1
        
        # 统计消气率
        total_notes = len(notes)
        resolved_notes = len([n for n in notes if n.get("is_resolved", False)])
        resolve_rate = (resolved_notes / total_notes * 100) if total_notes > 0 else 0
        
        # 获取成就数据
        achievement = await db.achievements.find_one({"user_id": user_id})
        
        return {
            "success": True,
            "statistics": {
                "total_notes": total_notes,
                "resolved_notes": resolved_notes,
                "resolve_rate": round(resolve_rate, 1),
                "emotion_counts": emotion_counts,
                "days": days,
                "achievement": {
                    "total_resolved": achievement.get("total_resolved", 0) if achievement else 0,
                    "current_level": achievement.get("current_level", 1) if achievement else 1,
                    "pet_stage": achievement.get("pet_stage", "egg") if achievement else "egg"
                } if achievement else None
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取统计数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")

@router.get("/achievement/{user_id}")
async def get_achievement(user_id: str):
    """获取用户成就数据"""
    db = get_database()
    
    try:
        achievement = await db.achievements.find_one({"user_id": user_id})
        
        if not achievement:
            # 创建初始成就
            user = await db.users.find_one({"_id": ObjectId(user_id)})
            achievement = {
                "user_id": user_id,
                "partner_id": user.get("partner_id"),
                "total_resolved": 0,
                "current_level": 1,
                "pet_stage": "egg",
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
            result = await db.achievements.insert_one(achievement)
            achievement["_id"] = str(result.inserted_id)
        else:
            achievement["_id"] = str(achievement["_id"])
        
        # 计算下一等级需要的消气次数
        next_level_requirement = achievement["current_level"] * 10
        progress = achievement["total_resolved"] % 10
        
        return {
            "success": True,
            "achievement": achievement,
            "next_level_requirement": next_level_requirement,
            "progress": progress
        }
    except Exception as e:
        print(f"获取成就数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")
