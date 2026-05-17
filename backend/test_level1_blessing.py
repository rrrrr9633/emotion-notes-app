"""
测试第一关AI祝福功能
"""
import asyncio
import os
from dotenv import load_dotenv

# 先加载环境变量
load_dotenv()

from ai_service import ai_service

async def test_level1_blessing():
    """测试AURA生成第一关祝福"""
    
    print("=" * 60)
    print("测试第一关AI祝福功能 - AURA")
    print("=" * 60)
    
    # 检查API Key配置
    api_key = os.getenv("DEEPSEEK_API_KEY", "")
    if api_key:
        print(f"✅ API Key已配置: {api_key[:10]}...{api_key[-4:]}")
    else:
        print("⚠️  警告: 未配置DEEPSEEK_API_KEY，将使用默认祝福")
    
    print(f"API Base: {os.getenv('DEEPSEEK_API_BASE', 'https://api.deepseek.com/v1')}")
    print(f"Model: {os.getenv('DEEPSEEK_MODEL', 'deepseek-chat')}")
    print("=" * 60)
    
    # 测试数据
    test_cases = [
        {
            "smell": "雨后",
            "first_words": "你好，我是小明",
            "metaphor": "两辆错轨的列车突然并线"
        },
        {
            "smell": "拿铁",
            "first_words": "我不记得内容，只记得声音很好听",
            "metaphor": "便利店最后一支融化的冰淇淋"
        },
        {
            "smell": "图书馆旧书",
            "first_words": "请问这个座位有人吗？",
            "metaphor": "冬日里突然飘落的第一片雪花"
        }
    ]
    
    for i, test_data in enumerate(test_cases, 1):
        print(f"\n【测试案例 {i}】")
        print(f"味道: {test_data['smell']}")
        print(f"第一句话: {test_data['first_words']}")
        print(f"比喻: {test_data['metaphor']}")
        print("\n生成中...")
        
        try:
            blessing = await ai_service.generate_level1_blessing(
                smell=test_data['smell'],
                first_words=test_data['first_words'],
                metaphor=test_data['metaphor']
            )
            
            print(f"\n💕 AURA的祝福：")
            print("-" * 60)
            print(blessing)
            print("-" * 60)
            
        except Exception as e:
            print(f"❌ 生成失败: {e}")
        
        if i < len(test_cases):
            print("\n" + "=" * 60)
            await asyncio.sleep(1)  # 避免API调用过快
    
    print("\n" + "=" * 60)
    print("测试完成！")
    print("=" * 60)

if __name__ == "__main__":
    asyncio.run(test_level1_blessing())
