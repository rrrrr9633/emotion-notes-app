from fastapi import APIRouter, HTTPException, status, UploadFile, File
from pydantic import BaseModel
from database import get_database
from bson import ObjectId
import os
import uuid

router = APIRouter()

class BindRequestModel(BaseModel):
    userId: str
    partnerUsername: str

class AcceptBindModel(BaseModel):
    requestId: str

class UpdateProfileModel(BaseModel):
    nickname: str = None
    relationship_start_date: str = None

@router.get("/profile/{user_id}")
async def get_user_profile(user_id: str):
    """获取用户资料"""
    db = get_database()
    
    try:
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 移除敏感信息
        user.pop('password_hash', None)
        user['_id'] = str(user['_id'])
        
        return {
            "success": True,
            "user": user
        }
    except Exception as e:
        print(f"获取用户资料失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.patch("/profile/{user_id}")
async def update_user_profile(user_id: str, profile: UpdateProfileModel):
    """更新用户资料"""
    db = get_database()
    
    try:
        update_data = {}
        if profile.nickname:
            update_data['nickname'] = profile.nickname
        if profile.relationship_start_date:
            update_data['relationship_start_date'] = profile.relationship_start_date
        
        if not update_data:
            raise HTTPException(status_code=400, detail="没有要更新的数据")
        
        result = await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": update_data}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        return {
            "success": True,
            "message": "资料更新成功"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"更新用户资料失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/upload-avatar/{user_id}")
async def upload_avatar(user_id: str, avatar: UploadFile = File(...)):
    """上传用户头像"""
    db = get_database()

    try:
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")

        # 删除旧头像文件
        old_avatar_url = user.get("avatar_url")
        if old_avatar_url and old_avatar_url.startswith("/uploads/avatars/"):
            old_file_path = old_avatar_url.lstrip("/")
            if os.path.exists(old_file_path):
                try:
                    os.remove(old_file_path)
                    print(f"已删除旧头像: {old_file_path}")
                except Exception as e:
                    print(f"删除旧头像失败: {e}")

        allowed = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
        ext = os.path.splitext(avatar.filename or "")[1].lower()
        if ext not in allowed:
            ext = ".jpg"

        upload_dir = "uploads/avatars"
        os.makedirs(upload_dir, exist_ok=True)

        unique_filename = f"{uuid.uuid4()}{ext}"
        file_path = os.path.join(upload_dir, unique_filename)

        content = await avatar.read()
        if len(content) > 5 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="图片不能超过5MB")

        with open(file_path, "wb") as f:
            f.write(content)

        avatar_url = f"/uploads/avatars/{unique_filename}"

        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {"avatar_url": avatar_url}},
        )

        return {
            "success": True,
            "avatar_url": avatar_url,
            "message": "头像上传成功",
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"上传头像失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")

@router.post("/bind-request")
async def send_bind_request(request: BindRequestModel):
    """发送绑定请求"""
    db = get_database()
    
    # 查找发送者
    sender = await db.users.find_one({"_id": ObjectId(request.userId)})
    if not sender:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 检查发送者是否已经绑定过
    if sender.get("is_partner_bound") or sender.get("partner_id"):
        raise HTTPException(status_code=400, detail="您已经绑定过伴侣，无法再次绑定")
    
    # 查找接收者
    receiver = await db.users.find_one({"username": request.partnerUsername})
    if not receiver:
        raise HTTPException(status_code=404, detail="对方用户不存在")
    
    # 检查接收者是否已经绑定过
    if receiver.get("is_partner_bound") or receiver.get("partner_id"):
        raise HTTPException(status_code=400, detail="对方已经绑定过伴侣，无法接受新的绑定请求")
    
    # 检查是否已发送过请求
    existing_request = await db.bind_requests.find_one({
        "from_user_id": request.userId,
        "to_username": request.partnerUsername,
        "status": "pending"
    })
    if existing_request:
        raise HTTPException(status_code=400, detail="已发送过绑定请求")
    
    # 创建绑定请求
    bind_request = {
        "from_user_id": request.userId,
        "from_username": sender["username"],
        "to_username": request.partnerUsername,
        "status": "pending"
    }
    
    result = await db.bind_requests.insert_one(bind_request)
    
    return {
        "success": True,
        "message": "绑定请求已发送",
        "requestId": str(result.inserted_id)
    }

@router.post("/accept-bind")
async def accept_bind_request(request: AcceptBindModel):
    """接受绑定请求"""
    db = get_database()
    
    # 查找绑定请求
    bind_request = await db.bind_requests.find_one({"_id": ObjectId(request.requestId)})
    if not bind_request:
        raise HTTPException(status_code=404, detail="绑定请求不存在")
    
    if bind_request["status"] != "pending":
        raise HTTPException(status_code=400, detail="该请求已处理")
    
    # 查找双方用户
    sender = await db.users.find_one({"_id": ObjectId(bind_request["from_user_id"])})
    receiver = await db.users.find_one({"username": bind_request["to_username"]})
    
    if not sender or not receiver:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 再次检查双方是否已经绑定过（防止在请求pending期间被其他人绑定）
    if sender.get("is_partner_bound") or sender.get("partner_id"):
        # 自动拒绝该请求
        await db.bind_requests.update_one(
            {"_id": ObjectId(request.requestId)},
            {"$set": {"status": "rejected"}}
        )
        raise HTTPException(status_code=400, detail="对方已经绑定过伴侣，该请求已自动拒绝")
    
    if receiver.get("is_partner_bound") or receiver.get("partner_id"):
        # 自动拒绝该请求
        await db.bind_requests.update_one(
            {"_id": ObjectId(request.requestId)},
            {"$set": {"status": "rejected"}}
        )
        raise HTTPException(status_code=400, detail="您已经绑定过伴侣，无法接受新的绑定请求")
    
    sender_id = str(sender["_id"])
    receiver_id = str(receiver["_id"])
    
    # 更新双方的partner_id
    await db.users.update_one(
        {"_id": ObjectId(sender_id)},
        {"$set": {"partner_id": receiver_id, "is_partner_bound": True}}
    )
    await db.users.update_one(
        {"_id": ObjectId(receiver_id)},
        {"$set": {"partner_id": sender_id, "is_partner_bound": True}}
    )
    
    # 更新请求状态
    await db.bind_requests.update_one(
        {"_id": ObjectId(request.requestId)},
        {"$set": {"status": "accepted"}}
    )
    
    return {
        "success": True,
        "message": "绑定成功",
        "partnerId": sender_id
    }

@router.get("/bind-requests/{user_id}")
async def get_pending_bind_requests(user_id: str):
    """获取待处理的绑定请求"""
    db = get_database()
    
    # 查找用户
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 查找发给该用户的待处理请求
    requests = await db.bind_requests.find({
        "to_username": user["username"],
        "status": "pending"
    }).to_list(length=100)
    
    # 转换ObjectId为字符串
    for req in requests:
        req["_id"] = str(req["_id"])
    
    return {
        "success": True,
        "requests": requests
    }


@router.post("/request-unbind/{user_id}")
async def request_unbind(user_id: str):
    """请求解绑（开始24小时冷静期）"""
    from datetime import timedelta
    db = get_database()
    
    try:
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user or not user.get('partner_id'):
            raise HTTPException(status_code=400, detail="未绑定伴侣")
        
        partner_id = user['partner_id']
        
        # 检查是否已有解绑请求
        existing = await db.unbind_requests.find_one({
            "$or": [
                {"requester_id": user_id, "status": "pending"},
                {"requester_id": partner_id, "status": "pending"}
            ]
        })
        
        if existing:
            raise HTTPException(status_code=400, detail="已有待处理的解绑请求")
        
        # 获取对方第四关的温柔话语
        partner_archive = await db.game_archives.find_one({"user_id": partner_id})
        soft_words = ""
        if partner_archive:
            soft_words = partner_archive.get('level4_phrase', '')
        
        # 创建解绑请求
        from datetime import datetime, timedelta
        now = datetime.utcnow()
        unbind_request = {
            "requester_id": user_id,
            "partner_id": partner_id,
            "created_at": now,
            "expires_at": now + timedelta(hours=24),
            "status": "pending",
            "soft_words": soft_words
        }
        
        result = await db.unbind_requests.insert_one(unbind_request)
        
        return {
            "success": True,
            "message": "解绑冷静期已开始（24小时）",
            "request_id": str(result.inserted_id),
            "soft_words": soft_words,
            "expires_at": unbind_request['expires_at'].isoformat()
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"请求解绑失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/cancel-unbind/{request_id}")
async def cancel_unbind(request_id: str, user_id: str):
    """取消解绑请求"""
    db = get_database()
    
    try:
        unbind_request = await db.unbind_requests.find_one({"_id": ObjectId(request_id)})
        if not unbind_request:
            raise HTTPException(status_code=404, detail="解绑请求不存在")
        
        # 双方都可以取消
        if unbind_request['requester_id'] != user_id and unbind_request['partner_id'] != user_id:
            raise HTTPException(status_code=403, detail="无权取消")
        
        await db.unbind_requests.update_one(
            {"_id": ObjectId(request_id)},
            {"$set": {"status": "cancelled"}}
        )
        
        return {
            "success": True,
            "message": "解绑请求已取消"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"取消解绑失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/unbind-status/{user_id}")
async def get_unbind_status(user_id: str):
    """获取解绑状态"""
    from datetime import datetime
    db = get_database()
    
    try:
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        partner_id = user.get('partner_id')
        if not partner_id:
            return {"success": True, "has_request": False}
        
        # 查找待处理的解绑请求
        unbind_request = await db.unbind_requests.find_one({
            "$or": [
                {"requester_id": user_id, "status": "pending"},
                {"requester_id": partner_id, "status": "pending"}
            ]
        })
        
        if not unbind_request:
            return {"success": True, "has_request": False}
        
        # 检查是否已过期
        now = datetime.utcnow()
        if now >= unbind_request['expires_at']:
            # 执行解绑
            await db.users.update_one(
                {"_id": ObjectId(user_id)},
                {"$set": {"partner_id": None, "is_partner_bound": False}}
            )
            await db.users.update_one(
                {"_id": ObjectId(partner_id)},
                {"$set": {"partner_id": None, "is_partner_bound": False}}
            )
            await db.unbind_requests.update_one(
                {"_id": unbind_request["_id"]},
                {"$set": {"status": "completed"}}
            )
            return {
                "success": True,
                "has_request": False,
                "message": "解绑已完成"
            }
        
        # 计算剩余时间
        remaining = unbind_request['expires_at'] - now
        
        return {
            "success": True,
            "has_request": True,
            "request_id": str(unbind_request['_id']),
            "is_requester": unbind_request['requester_id'] == user_id,
            "soft_words": unbind_request.get('soft_words', ''),
            "expires_at": unbind_request['expires_at'].isoformat(),
            "remaining_hours": remaining.total_seconds() / 3600
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取解绑状态失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/memories/{user_id}")
async def get_memories(user_id: str):
    """获取回忆（对方的游戏数据）"""
    db = get_database()
    
    try:
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user or not user.get('partner_id'):
            raise HTTPException(status_code=400, detail="未绑定伴侣")
        
        partner_id = user['partner_id']
        
        # 获取对方的游戏存档
        archive = await db.game_archives.find_one({"user_id": partner_id})
        
        if not archive:
            return {
                "success": True,
                "memories": {}
            }
        
        # 整理回忆数据
        memories = {
            "level1": {
                "smell": archive.get('level1_smell'),
                "first_words": archive.get('level1_first_words'),
                "metaphor": archive.get('level1_metaphor'),
                "blessing": archive.get('level1_blessing'),
            },
            "level2": {
                "color": archive.get('level2_color'),
                "dialogue": archive.get('level2_dialogue'),
                "song": archive.get('level2_song'),
                "photo_url": archive.get('level2_photo_url'),
                "blessing": archive.get('level2_blessing'),
            },
            "level3": {
                "node1": archive.get('level3_node1'),
                "node2": archive.get('level3_node2'),
                "node3": archive.get('level3_node3'),
                "blessing": archive.get('level3_blessing'),
            },
            "level4": {
                "action": archive.get('level4_action'),
                "phrase": archive.get('level4_phrase'),
                "ritual": archive.get('level4_ritual'),
                "forgive_message": archive.get('level4_forgive_message'),
                "blessing": archive.get('level4_blessing'),
            }
        }
        
        return {
            "success": True,
            "memories": memories
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"获取回忆失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))
