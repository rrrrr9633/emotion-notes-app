from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from bson import ObjectId

class PyObjectId(ObjectId):
    @classmethod
    def __get_validators__(cls):
        yield cls.validate

    @classmethod
    def validate(cls, v):
        if not ObjectId.is_valid(v):
            raise ValueError("Invalid ObjectId")
        return ObjectId(v)

    @classmethod
    def __get_pydantic_json_schema__(cls, field_schema):
        field_schema.update(type="string")

# 用户模型
class UserCreate(BaseModel):
    username: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class User(BaseModel):
    id: Optional[PyObjectId] = Field(alias="_id", default=None)
    username: str
    password_hash: str
    partner_id: Optional[str] = None
    is_partner_bound: bool = False
    onboarding_completed: bool = False
    current_level: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}

# 绑定请求模型
class BindRequest(BaseModel):
    id: Optional[PyObjectId] = Field(alias="_id", default=None)
    from_user_id: str
    from_username: str
    to_username: str
    status: str = "pending"  # pending, accepted, rejected
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}

# 便利贴模型
class NoteCreate(BaseModel):
    title: Optional[str] = None
    content: str
    emotion_tag: str
    audio_url: Optional[str] = None  # 语音便利贴URL

class NoteUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    emotion_tag: Optional[str] = None
    is_resolved: Optional[bool] = None

class Note(BaseModel):
    id: Optional[PyObjectId] = Field(alias="_id", default=None)
    user_id: str
    title: Optional[str] = None
    content: str
    emotion_tag: str  # 生气、难过、委屈、失望、焦虑
    audio_url: Optional[str] = None
    ai_reply: Optional[str] = None
    is_resolved: bool = False  # 是否已消气
    status: str = "active"  # active, archived, deleted
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    resolved_at: Optional[datetime] = None  # 消气时间

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}

# 成就系统模型
class Achievement(BaseModel):
    id: Optional[PyObjectId] = Field(alias="_id", default=None)
    user_id: str
    partner_id: Optional[str] = None
    total_resolved: int = 0  # 总共消气次数
    current_level: int = 1  # 当前等级
    pet_stage: str = "egg"  # egg, baby, child, teen, adult
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
