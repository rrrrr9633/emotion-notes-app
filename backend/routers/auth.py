from fastapi import APIRouter, HTTPException, status
from models import UserCreate, UserLogin
from database import get_database
from auth_utils import get_password_hash, verify_password, create_access_token
from bson import ObjectId
import re

router = APIRouter()

def contains_chinese(text: str) -> bool:
    """检查字符串是否包含中文字符"""
    return bool(re.search(r'[\u4e00-\u9fff]', text))

@router.post("/register")
async def register(user: UserCreate):
    """用户注册"""
    db = get_database()
    
    # 检查用户名是否包含中文
    if contains_chinese(user.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户名不能使用中文"
        )
    
    # 检查用户名是否已存在
    existing_user = await db.users.find_one({"username": user.username})
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户名已存在"
        )
    
    # 创建新用户
    user_dict = {
        "username": user.username,
        "password_hash": get_password_hash(user.password),
        "partner_id": None,
        "is_partner_bound": False,
        "onboarding_completed": False,
    }
    
    result = await db.users.insert_one(user_dict)
    user_id = str(result.inserted_id)
    
    # 生成token
    access_token = create_access_token(data={"sub": user_id, "username": user.username})
    
    return {
        "success": True,
        "message": "注册成功",
        "userId": user_id,
        "username": user.username,
        "access_token": access_token,
        "token_type": "bearer"
    }

@router.post("/login")
async def login(user: UserLogin):
    """用户登录"""
    db = get_database()
    
    # 查找用户
    db_user = await db.users.find_one({"username": user.username})
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    
    # 验证密码
    if not verify_password(user.password, db_user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    
    user_id = str(db_user["_id"])
    
    # 生成token
    access_token = create_access_token(data={"sub": user_id, "username": user.username})
    
    return {
        "success": True,
        "message": "登录成功",
        "userId": user_id,
        "username": user.username,
        "partnerId": db_user.get("partner_id"),
        "isPartnerBound": db_user.get("is_partner_bound", False),
        "access_token": access_token,
        "token_type": "bearer"
    }
