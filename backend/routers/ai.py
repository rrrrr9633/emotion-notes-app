from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from ai_service import ai_service

router = APIRouter()

class PersonalityUpdate(BaseModel):
    personality: str

@router.get("/personality")
async def get_personality():
    """获取当前AI性格配置"""
    return {
        "success": True,
        "personality": ai_service.get_current_personality()
    }

@router.post("/personality")
async def update_personality(data: PersonalityUpdate):
    """更新AI性格配置"""
    success = ai_service.update_personality(data.personality)
    
    if success:
        return {
            "success": True,
            "message": "AI性格配置已更新"
        }
    else:
        raise HTTPException(status_code=500, detail="更新失败")

@router.post("/personality/reload")
async def reload_personality():
    """重新加载AI性格配置（从文件）"""
    ai_service.reload_personality()
    return {
        "success": True,
        "message": "AI性格配置已重新加载",
        "personality": ai_service.get_current_personality()
    }

@router.post("/test")
async def test_ai(content: str, emotion_tag: str):
    """测试AI回复"""
    try:
        reply = await ai_service.generate_reply(
            content=content,
            emotion_tag=emotion_tag
        )
        return {
            "success": True,
            "reply": reply
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"测试失败: {str(e)}")
