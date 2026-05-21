from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import httpx
from ai_service import ai_service

router = APIRouter()


@router.get("/health")
async def ai_health():
    """检查 AI 配置与 DeepSeek 连通性（运维排查用）"""
    configured = ai_service.is_configured()
    result = {
        "success": True,
        "configured": configured,
        "api_base": ai_service.api_base,
        "model": ai_service.model,
        "deepseek_reachable": False,
        "message": "",
    }
    if not configured:
        result["message"] = "未配置 DEEPSEEK_API_KEY，请检查 backend/.env"
        return result

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(f"{ai_service.api_base}/models", headers={
                "Authorization": f"Bearer {ai_service.api_key}",
            })
        result["deepseek_reachable"] = resp.status_code < 500
        result["message"] = f"DeepSeek 响应 HTTP {resp.status_code}"
    except Exception as e:
        result["message"] = f"无法连接 DeepSeek: {e}"

    return result

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
            "reply": reply,
            "ai_generated": ai_service.is_configured(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"测试失败: {str(e)}")
