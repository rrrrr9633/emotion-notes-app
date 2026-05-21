"""
管理后台API
仅供管理员使用，不对外开放
"""
from fastapi import APIRouter, HTTPException, Header
from database import get_database
from auth_utils import get_password_hash
from bson import ObjectId
from datetime import datetime
from typing import Optional

router = APIRouter()

# 简单的管理员密钥验证（生产环境应该使用更安全的方式）
ADMIN_SECRET = "emotion_admin_2024"  # 请修改为你自己的密钥

def verify_admin(admin_key: Optional[str] = Header(None)):
    """验证管理员权限"""
    if admin_key != ADMIN_SECRET:
        raise HTTPException(status_code=403, detail="无权访问")
    return True

@router.get("/users")
async def get_all_users(admin_key: Optional[str] = Header(None)):
    """获取所有用户列表"""
    verify_admin(admin_key)
    db = get_database()
    
    users = await db.users.find().to_list(length=1000)
    
    # 转换数据
    user_list = []
    for user in users:
        user_info = {
            "_id": str(user["_id"]),
            "username": user.get("username"),
            "nickname": user.get("nickname"),
            "partner_id": user.get("partner_id"),
            "is_partner_bound": user.get("is_partner_bound", False),
            "onboarding_completed": user.get("onboarding_completed", False),
            "created_at": user.get("created_at"),
            "avatar_url": user.get("avatar_url"),
        }
        
        # 获取伴侣信息
        if user.get("partner_id"):
            partner = await db.users.find_one({"_id": ObjectId(user["partner_id"])})
            if partner:
                user_info["partner_username"] = partner.get("username")
        
        # 获取便利贴数量
        notes_count = await db.notes.count_documents({"user_id": str(user["_id"])})
        user_info["notes_count"] = notes_count
        
        user_list.append(user_info)
    
    return {
        "success": True,
        "users": user_list,
        "total": len(user_list)
    }

@router.delete("/users/{user_id}")
async def delete_user(user_id: str, admin_key: Optional[str] = Header(None)):
    """删除用户及其所有数据"""
    verify_admin(admin_key)
    db = get_database()
    
    try:
        # 检查用户是否存在
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 如果有伴侣，解除绑定
        if user.get("partner_id"):
            await db.users.update_one(
                {"_id": ObjectId(user["partner_id"])},
                {"$set": {
                    "partner_id": None,
                    "is_partner_bound": False
                }}
            )
        
        # 删除用户的所有便利贴
        await db.notes.delete_many({"user_id": user_id})
        
        # 删除用户的留言
        await db.note_comments.delete_many({"user_id": user_id})
        
        # 删除用户的成就数据
        await db.achievements.delete_many({"user_id": user_id})
        
        # 删除用户的游戏数据
        await db.game_progress.delete_many({"user_id": user_id})
        
        # 删除解绑申请
        await db.unbind_requests.delete_many({
            "$or": [
                {"requester_id": user_id},
                {"target_id": user_id}
            ]
        })
        
        # 删除用户
        await db.users.delete_one({"_id": ObjectId(user_id)})
        
        return {
            "success": True,
            "message": f"用户 {user.get('username')} 及其所有数据已删除"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"删除失败: {str(e)}")

@router.post("/unbind-requests/{request_id}/approve")
async def approve_unbind_request(request_id: str, admin_key: Optional[str] = Header(None)):
    """管理员快速通过解绑申请（无需等待24小时）"""
    verify_admin(admin_key)
    db = get_database()
    
    try:
        # 查找解绑申请
        request = await db.unbind_requests.find_one({"_id": ObjectId(request_id)})
        if not request:
            raise HTTPException(status_code=404, detail="解绑申请不存在")
        
        if request["status"] != "pending":
            raise HTTPException(status_code=400, detail="该申请已处理")
        
        requester_id = request["requester_id"]
        target_id = request["target_id"]
        
        # 解除双方绑定
        await db.users.update_one(
            {"_id": ObjectId(requester_id)},
            {"$set": {
                "partner_id": None,
                "is_partner_bound": False
            }}
        )
        
        await db.users.update_one(
            {"_id": ObjectId(target_id)},
            {"$set": {
                "partner_id": None,
                "is_partner_bound": False
            }}
        )
        
        # 更新申请状态
        await db.unbind_requests.update_one(
            {"_id": ObjectId(request_id)},
            {"$set": {
                "status": "approved_by_admin",
                "approved_at": datetime.utcnow()
            }}
        )
        
        return {
            "success": True,
            "message": "解绑申请已通过"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"操作失败: {str(e)}")

@router.get("/unbind-requests")
async def get_unbind_requests(admin_key: Optional[str] = Header(None)):
    """获取所有解绑申请"""
    verify_admin(admin_key)
    db = get_database()
    
    requests = await db.unbind_requests.find({"status": "pending"}).to_list(length=100)
    
    request_list = []
    for req in requests:
        requester = await db.users.find_one({"_id": ObjectId(req["requester_id"])})
        target = await db.users.find_one({"_id": ObjectId(req["target_id"])})
        
        request_list.append({
            "_id": str(req["_id"]),
            "requester_username": requester.get("username") if requester else "未知",
            "target_username": target.get("username") if target else "未知",
            "created_at": req["created_at"].isoformat(),
            "expires_at": req["expires_at"].isoformat(),
            "status": req["status"]
        })
    
    return {
        "success": True,
        "requests": request_list
    }

@router.post("/users/{user_id}/reset-password")
async def reset_user_password(
    user_id: str, 
    new_password: str,
    admin_key: Optional[str] = Header(None)
):
    """重置用户密码"""
    verify_admin(admin_key)
    db = get_database()
    
    try:
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 更新密码
        new_password_hash = get_password_hash(new_password)
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {"password_hash": new_password_hash}}
        )
        
        return {
            "success": True,
            "message": f"用户 {user.get('username')} 的密码已重置"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"重置失败: {str(e)}")

@router.get("/users/{user_id}")
async def get_user_detail(user_id: str, admin_key: Optional[str] = Header(None)):
    """获取用户详细信息"""
    verify_admin(admin_key)
    db = get_database()
    
    try:
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(status_code=404, detail="用户不存在")
        
        # 获取伴侣信息
        partner_info = None
        if user.get("partner_id"):
            partner = await db.users.find_one({"_id": ObjectId(user["partner_id"])})
            if partner:
                partner_info = {
                    "_id": str(partner["_id"]),
                    "username": partner.get("username"),
                    "nickname": partner.get("nickname")
                }
        
        # 获取便利贴统计
        notes_count = await db.notes.count_documents({"user_id": user_id})
        resolved_count = await db.notes.count_documents({
            "user_id": user_id,
            "is_resolved": True
        })
        
        # 获取成就数据
        achievement = await db.achievements.find_one({"user_id": user_id})
        
        user_detail = {
            "_id": str(user["_id"]),
            "username": user.get("username"),
            "nickname": user.get("nickname"),
            "avatar_url": user.get("avatar_url"),
            "partner_id": user.get("partner_id"),
            "partner_info": partner_info,
            "is_partner_bound": user.get("is_partner_bound", False),
            "onboarding_completed": user.get("onboarding_completed", False),
            "together_since": user.get("together_since"),
            "notes_count": notes_count,
            "resolved_count": resolved_count,
            "achievement": {
                "total_resolved": achievement.get("total_resolved", 0) if achievement else 0,
                "current_level": achievement.get("current_level", 1) if achievement else 1,
                "pet_stage": achievement.get("pet_stage", "egg") if achievement else "egg"
            } if achievement else None
        }
        
        return {
            "success": True,
            "user": user_detail
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取失败: {str(e)}")
