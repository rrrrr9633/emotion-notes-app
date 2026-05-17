"""
AI功能测试脚本
"""
import asyncio
from ai_service import ai_service

async def test_ai():
    print("=" * 50)
    print("AI功能测试")
    print("=" * 50)
    
    # 测试用例
    test_cases = [
        {
            "content": "今天工作上被领导批评了，感觉很委屈",
            "emotion_tag": "委屈",
            "title": "工作不顺"
        },
        {
            "content": "和TA吵架了，现在很生气",
            "emotion_tag": "生气",
            "title": None
        },
        {
            "content": "考试没考好，很失望",
            "emotion_tag": "失望",
            "title": "考试失利"
        }
    ]
    
    for i, case in enumerate(test_cases, 1):
        print(f"\n测试 {i}:")
        print(f"标题: {case['title']}")
        print(f"内容: {case['content']}")
        print(f"情绪: {case['emotion_tag']}")
        print("-" * 50)
        
        reply = await ai_service.generate_reply(
            content=case['content'],
            emotion_tag=case['emotion_tag'],
            title=case['title']
        )
        
        print(f"AI回复:\n{reply}")
        print("=" * 50)

if __name__ == "__main__":
    asyncio.run(test_ai())
