from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
from dotenv import load_dotenv
import os

from database import connect_to_mongo, close_mongo_connection
from routers import auth, user, notes, game, ai, onboarding

load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动时连接数据库
    await connect_to_mongo()
    yield
    # 关闭时断开数据库
    await close_mongo_connection()

app = FastAPI(
    title="情绪便利贴 API",
    description="情侣情绪管理应用后端API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境需要限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(auth.router, prefix="/api/auth", tags=["认证"])
app.include_router(user.router, prefix="/api/user", tags=["用户"])
app.include_router(notes.router, prefix="/api/notes", tags=["便利贴"])
app.include_router(game.router, prefix="/api/game", tags=["游戏"])
app.include_router(ai.router, prefix="/api/ai", tags=["AI管理"])
app.include_router(onboarding.router, prefix="/api/onboarding", tags=["初始配置"])

@app.get("/")
async def root():
    return {
        "message": "欢迎使用情绪便利贴API",
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host=host, port=port, reload=True)
