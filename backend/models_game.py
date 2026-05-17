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

# 游戏数据永久存档模型 - 每个用户独立存储
class GameArchive(BaseModel):
    id: Optional[PyObjectId] = Field(alias="_id", default=None)
    user_id: str  # 用户唯一标识，作为主键之一
    partner_id: Optional[str] = None
    
    # 第一关数据
    level1_smell: Optional[str] = None
    level1_first_words: Optional[str] = None
    level1_metaphor: Optional[str] = None
    level1_blessing: Optional[str] = None
    level1_completed_at: Optional[datetime] = None
    
    # 第二关数据
    level2_color: Optional[str] = None
    level2_dialogue: Optional[str] = None
    level2_song: Optional[str] = None
    level2_photo_url: Optional[str] = None
    level2_blessing: Optional[str] = None
    level2_completed_at: Optional[datetime] = None
    
    # 第三关数据
    level3_habit: Optional[str] = None
    level3_moment: Optional[str] = None
    level3_future_plan: Optional[str] = None
    level3_blessing: Optional[str] = None
    level3_completed_at: Optional[datetime] = None
    
    # 第四关数据
    level4_action: Optional[str] = None
    level4_phrase: Optional[str] = None
    level4_ritual: Optional[str] = None
    level4_forgive_message: Optional[str] = None
    level4_blessing: Optional[str] = None
    level4_completed_at: Optional[datetime] = None
    
    # 整体完成时间
    all_completed_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}
        # 确保user_id的唯一性索引在数据库层面实现

# 各关卡提交数据模型
class Level1Submit(BaseModel):
    user_id: str
    smell: str
    first_words: str
    metaphor: str
    blessing: str

class Level2Submit(BaseModel):
    user_id: str
    color: str
    dialogue: str
    song: str
    photo_url: str
    blessing: str

class Level3Submit(BaseModel):
    user_id: str
    habit: str
    moment: str
    future_plan: str
    blessing: str

class Level4Submit(BaseModel):
    user_id: str
    action: str
    phrase: str
    ritual: str
    forgive_message: str
    blessing: str
