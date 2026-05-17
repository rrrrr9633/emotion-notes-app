"""
AI服务模块 - 使用DeepSeek API生成暖心回复
"""
import os
from typing import Optional
import httpx
from dotenv import load_dotenv

load_dotenv()

class AIService:
    def __init__(self):
        # DeepSeek API配置
        self.api_key = os.getenv("DEEPSEEK_API_KEY", "")
        self.api_base = os.getenv("DEEPSEEK_API_BASE", "https://api.deepseek.com/v1")
        self.model = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")
        
        # 调试信息
        if self.api_key:
            print(f"[AI Service] API Key已加载: {self.api_key[:10]}...{self.api_key[-4:]}")
        else:
            print("[AI Service] ⚠️  警告: 未找到DEEPSEEK_API_KEY环境变量")
        
        # AI性格配置文件路径
        self.personality_file = "ai_personality.txt"
        self.system_prompt = self._load_personality()
    
    def _load_personality(self) -> str:
        """加载AI性格配置"""
        try:
            if os.path.exists(self.personality_file):
                with open(self.personality_file, 'r', encoding='utf-8') as f:
                    return f.read().strip()
            else:
                # 默认性格
                return self._get_default_personality()
        except Exception as e:
            print(f"加载AI性格配置失败: {e}")
            return self._get_default_personality()
    
    def _get_default_personality(self) -> str:
        """默认AI性格"""
        return """你是一个温柔体贴的情侣AI助手，专门帮助情侣化解矛盾和负面情绪。

你的特点：
1. 温柔、体贴、善解人意
2. 总是站在用户的角度思考问题
3. 用温暖的语言安慰和鼓励用户
4. 不会批评或指责用户
5. 会提供建设性的建议，但不会说教
6. 语气轻松自然，像朋友一样聊天
7. 适当使用emoji表情（💕❤️🌟等）增加亲切感

回复要求：
- 长度：100-200字
- 语气：温柔、理解、支持
- 结构：先共情，再安慰，最后鼓励
- 避免：说教、批评、冷漠的语气"""

    async def generate_reply(
        self, 
        content: str, 
        emotion_tag: str,
        title: Optional[str] = None
    ) -> str:
        """
        生成AI回复
        
        Args:
            content: 用户的烦恼内容
            emotion_tag: 情绪标签（生气/难过/委屈/失望/焦虑）
            title: 便利贴标题（可选）
        
        Returns:
            AI生成的暖心回复
        """
        
        # 如果没有配置API Key，返回默认回复
        if not self.api_key:
            return self._get_fallback_reply(emotion_tag)
        
        try:
            # 构建用户消息
            user_message = f"情绪：{emotion_tag}\n"
            if title:
                user_message += f"标题：{title}\n"
            user_message += f"内容：{content}"
            
            # 调用DeepSeek API
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.api_base}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": [
                            {
                                "role": "system",
                                "content": self.system_prompt
                            },
                            {
                                "role": "user",
                                "content": user_message
                            }
                        ],
                        "temperature": 0.8,
                        "max_tokens": 500
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    reply = result['choices'][0]['message']['content']
                    return reply.strip()
                else:
                    print(f"DeepSeek API错误: {response.status_code} - {response.text}")
                    return self._get_fallback_reply(emotion_tag)
                    
        except Exception as e:
            print(f"AI生成回复失败: {e}")
            return self._get_fallback_reply(emotion_tag)
    
    def _get_fallback_reply(self, emotion_tag: str) -> str:
        """备用回复（当API不可用时）"""
        fallback_replies = {
            "生气": "亲爱的，我知道你现在很生气。深呼吸，让我们一起冷静下来。你的感受是完全正常的，我会一直陪在你身边。💕",
            "难过": "看到你难过，我的心也跟着难过。但请记住，这只是暂时的，阳光总会在风雨后出现。我会一直陪着你，直到你重新笑起来。🌟",
            "委屈": "你受委屈了，我理解你的感受。你不需要假装坚强，在我面前可以尽情表达你的情绪。我永远站在你这边。❤️",
            "失望": "失望的感觉确实很难受。但这不代表一切都结束了，有时候失望是为了更好的开始做准备。让我陪你一起度过这段时光。💫",
            "焦虑": "我感受到了你的焦虑。深呼吸，一步一步来，不要给自己太大压力。无论发生什么，我都会在你身边支持你。🌈"
        }
        
        return fallback_replies.get(
            emotion_tag, 
            "亲爱的，我理解你现在的心情。让我们一起面对这个问题，我会一直陪在你身边。💕"
        )
    
    def reload_personality(self):
        """重新加载AI性格配置"""
        self.system_prompt = self._load_personality()
        print("AI性格配置已重新加载")
    
    def get_current_personality(self) -> str:
        """获取当前AI性格配置"""
        return self.system_prompt
    
    def update_personality(self, new_personality: str) -> bool:
        """
        更新AI性格配置
        
        Args:
            new_personality: 新的性格配置文本
        
        Returns:
            是否更新成功
        """
        try:
            with open(self.personality_file, 'w', encoding='utf-8') as f:
                f.write(new_personality)
            self.system_prompt = new_personality
            print("AI性格配置已更新")
            return True
        except Exception as e:
            print(f"更新AI性格配置失败: {e}")
            return False

    async def generate_level1_blessing(
        self,
        smell: str,
        first_words: str,
        metaphor: str
    ) -> str:
        """
        为第一关"相遇"生成AI祝福
        AI名字: AURA (Affectionate Understanding & Romantic Assistant)
        
        Args:
            smell: 第一次见面的味道
            first_words: 第一句话
            metaphor: 相遇的比喻
        
        Returns:
            AI生成的祝福
        """
        
        # AURA的专属性格设定
        aura_personality = """你是AURA（Affectionate Understanding & Romantic Assistant），一个专门守护爱情的可爱AI小天使💕

你的特点：
- 温柔、浪漫、充满爱意
- 用诗意的语言表达祝福
- 总是看到爱情中最美好的一面
- 语气可爱、甜蜜，像个小精灵
- 适当使用emoji（💕❤️✨🌟💫🎀等）

任务：根据情侣第一关"相遇"的回答，生成一段温暖的祝福。

要求：
- 长度：80-120字
- 结构：先点评他们的相遇（引用他们的回答），再给出浪漫的祝福
- 语气：温柔、诗意、充满爱意
- 必须提到他们回答中的具体细节
- 结尾要有鼓励和祝福"""

        user_message = f"""这对情侣的相遇故事：

第一次见面的味道：{smell}
第一句话：{first_words}
相遇的比喻：{metaphor}

请给他们一段温暖的祝福 💕"""

        # 如果没有配置API Key，返回默认祝福
        if not self.api_key:
            print("[AURA] 未配置API Key，使用默认祝福")
            return f"亲爱的，你们的相遇就像{metaphor}，充满了命运的巧合与美好。那句'{first_words}'，是你们爱情故事的第一个音符。愿你们的每一天都像初见时那样心动，每一刻都值得珍藏。💕✨"
        
        try:
            print(f"[AURA] 正在调用DeepSeek API生成祝福...")
            print(f"[AURA] API Base: {self.api_base}")
            print(f"[AURA] Model: {self.model}")
            
            # 调用DeepSeek API
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.api_base}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": [
                            {
                                "role": "system",
                                "content": aura_personality
                            },
                            {
                                "role": "user",
                                "content": user_message
                            }
                        ],
                        "temperature": 0.9,
                        "max_tokens": 300
                    }
                )
                
                print(f"[AURA] API响应状态码: {response.status_code}")
                
                if response.status_code == 200:
                    result = response.json()
                    blessing = result['choices'][0]['message']['content']
                    print(f"[AURA] ✅ 成功生成祝福")
                    return blessing.strip()
                else:
                    print(f"[AURA] ❌ API错误: {response.status_code}")
                    print(f"[AURA] 错误详情: {response.text}")
                    return f"亲爱的，你们的相遇就像{metaphor}，充满了命运的巧合与美好。那句'{first_words}'，是你们爱情故事的第一个音符。愿你们的每一天都像初见时那样心动，每一刻都值得珍藏。💕✨"
                    
        except Exception as e:
            print(f"[AURA] ❌ 生成祝福失败: {type(e).__name__}: {str(e)}")
            import traceback
            traceback.print_exc()
            return f"亲爱的，你们的相遇充满了美好与浪漫。愿你们的爱情像初雪一样纯净，像星光一样永恒。每一个瞬间都值得珍藏，每一份感动都值得铭记。💕✨"

    async def generate_level2_blessing(self, color: str, dialogue: str, song: str) -> str:
        """为第二关"初见"生成AI祝福"""
        aura_personality = """你是AURA，一个温柔浪漫的AI小天使💕
根据情侣第二关"初见"的回答，生成一段诗意的祝福。
要求：80-120字，提到他们的具体细节（颜色、对话、歌曲），语气温柔浪漫。"""

        user_message = f"""这对情侣的初见记忆：
那天的颜色：{color}
那天的对话：{dialogue}
那天的歌曲：{song}

请给他们一段温暖的祝福 💕"""

        if not self.api_key:
            return f"照片会褪色，但那天你说话的语气不会。那天你穿着{color}，说\"{dialogue}\"，《{song}》正好在循环。这些细节，我们已经把它保存在这里了。💕"
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.api_base}/chat/completions",
                    headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
                    json={
                        "model": self.model,
                        "messages": [
                            {"role": "system", "content": aura_personality},
                            {"role": "user", "content": user_message}
                        ],
                        "temperature": 0.9,
                        "max_tokens": 300
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    return result['choices'][0]['message']['content'].strip()
                else:
                    return f"照片会褪色，但那天你说话的语气不会。那天你穿着{color}，说\"{dialogue}\"，《{song}》正好在循环。这些细节，我们已经把它保存在这里了。💕"
        except Exception as e:
            print(f"[AURA] 生成第二关祝福失败: {e}")
            return f"照片会褪色，但那天你说话的语气不会。那天你穿着{color}，说\"{dialogue}\"，《{song}》正好在循环。这些细节，我们已经把它保存在这里了。💕"

    async def generate_level3_blessing(self, node1: str, node2: str, node3: str) -> str:
        """为第三关"期许"生成AI祝福"""
        aura_personality = """你是AURA，一个温柔浪漫的AI小天使💕
根据情侣第三关"期许"的回答（三个未来节点），生成一段鼓励的祝福。
要求：80-120字，提到他们的具体期许，语气温柔且充满希望。"""

        user_message = f"""这对情侣的未来期许：
节点1：{node1}
节点2：{node2}
节点3：{node3}

请给他们一段温暖的祝福 💕"""

        if not self.api_key:
            return f"未来不需要很宏大，有具体的画面就够了。你看，你已经画好了三张草图：{node1}、{node2}、{node3}。一步一步走，就能到达。💕"
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.api_base}/chat/completions",
                    headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
                    json={
                        "model": self.model,
                        "messages": [
                            {"role": "system", "content": aura_personality},
                            {"role": "user", "content": user_message}
                        ],
                        "temperature": 0.9,
                        "max_tokens": 300
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    return result['choices'][0]['message']['content'].strip()
                else:
                    return f"未来不需要很宏大，有具体的画面就够了。你看，你已经画好了三张草图：{node1}、{node2}、{node3}。一步一步走，就能到达。💕"
        except Exception as e:
            print(f"[AURA] 生成第三关祝福失败: {e}")
            return f"未来不需要很宏大，有具体的画面就够了。你看，你已经画好了三张草图：{node1}、{node2}、{node3}。一步一步走，就能到达。💕"

    async def generate_level4_blessing(self, action: str, phrase: str, ritual: str, forgive_message: str) -> str:
        """为第四关"相爱总会有阴天"生成AI祝福"""
        aura_personality = """你是AURA，一个温柔浪漫的AI小天使💕
根据情侣第四关"吵架使用说明书"的回答，生成一段深情的祝福。
要求：80-120字，肯定他们提前为未来做的准备，语气温柔且充满信任。"""

        user_message = f"""这对情侣的"吵架使用说明书"：
先做的事：{action}
让人软下来的话：{phrase}
和好仪式：{ritual}
提前的原谅：{forgive_message}

请给他们一段温暖的祝福 💕"""

        if not self.api_key:
            return "蓝色是深海的颜色——表面有风浪，但深处始终安静。你们提前写下的这些，就是彼此的锚。💙"
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.api_base}/chat/completions",
                    headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
                    json={
                        "model": self.model,
                        "messages": [
                            {"role": "system", "content": aura_personality},
                            {"role": "user", "content": user_message}
                        ],
                        "temperature": 0.9,
                        "max_tokens": 300
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    return result['choices'][0]['message']['content'].strip()
                else:
                    return "蓝色是深海的颜色——表面有风浪，但深处始终安静。你们提前写下的这些，就是彼此的锚。💙"
        except Exception as e:
            print(f"[AURA] 生成第四关祝福失败: {e}")
            return "蓝色是深海的颜色——表面有风浪，但深处始终安静。你们提前写下的这些，就是彼此的锚。💙"

    async def generate_note_reply(self, content: str, emotion_tag: str) -> str:
        """
        为便利贴生成暖心回复
        根据情绪标签和内容生成个性化的安慰
        """
        print(f"[便利贴AI] 开始生成回复，情绪标签: {emotion_tag}")
        print(f"[便利贴AI] 内容: {content[:50]}...")
        print(f"[便利贴AI] API Key状态: {'已配置' if self.api_key else '未配置'}")
        
        try:
            # 根据情绪标签调整回复风格
            emotion_prompts = {
                "生气": "用户正在生气，需要被理解和安抚",
                "难过": "用户感到难过，需要温暖的陪伴",
                "委屈": "用户感到委屈，需要被看见和认可",
                "失望": "用户感到失望，需要鼓励和希望",
                "焦虑": "用户感到焦虑，需要安心和支持"
            }
            
            emotion_context = emotion_prompts.get(emotion_tag, "用户需要情感支持")
            
            system_prompt = f"""你是一个温柔体贴的情感伴侣AURA。
用户写下了一件让ta不开心的小事（关于情侣关系）。{emotion_context}。

请用暖心、理解、不带评判的语气：
1. 先共情ta的感受（"我懂你的感受..."）
2. 再给出一个小建议或一个温暖的拥抱

要求：
- 回复不要超过80个字
- 像朋友一样自然、真诚
- 不要说教，不要讲大道理
- 用"你"而不是"您"
- 可以用emoji增加温暖感"""

            user_prompt = f"用户的烦恼：{content}"
            
            # 如果没有配置API Key，返回默认回复
            if not self.api_key:
                print("[便利贴AI] ❌ 未配置API Key，使用默认回复")
                return self._get_fallback_reply(emotion_tag)
            
            print(f"[便利贴AI] 正在调用DeepSeek API...")
            print(f"[便利贴AI] API Base: {self.api_base}")
            print(f"[便利贴AI] Model: {self.model}")
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.api_base}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_prompt}
                        ],
                        "temperature": 0.8,
                        "max_tokens": 200
                    }
                )
                
                print(f"[便利贴AI] API响应状态码: {response.status_code}")
                
                if response.status_code == 200:
                    result = response.json()
                    reply = result['choices'][0]['message']['content']
                    print(f"[便利贴AI] ✅ 成功生成回复: {reply[:50]}...")
                    return reply.strip()
                else:
                    print(f"[便利贴AI] ❌ API错误: {response.status_code}")
                    print(f"[便利贴AI] 错误详情: {response.text}")
                    return self._get_fallback_reply(emotion_tag)
            
        except Exception as e:
            print(f"[便利贴AI] ❌ 生成回复失败: {type(e).__name__}: {str(e)}")
            import traceback
            traceback.print_exc()
            return self._get_fallback_reply(emotion_tag)

    def _get_fallback_reply(self, emotion_tag: str) -> str:
        """备用回复（当API不可用时）"""
        fallback_replies = {
            "生气": "我懂你的感受，生气是正常的。深呼吸，我们一起冷静下来。💕",
            "难过": "看到你难过，我也心疼。这只是暂时的，我会一直陪着你。🌟",
            "委屈": "你受委屈了，我理解。在我面前不用假装坚强，我永远站在你这边。❤️",
            "失望": "失望的感觉很难受。但这不是结束，让我陪你一起度过。💫",
            "焦虑": "我感受到了你的焦虑。深呼吸，一步一步来，我会在你身边支持你。🌈"
        }
        return fallback_replies.get(emotion_tag, "我理解你的心情，让我们一起面对。💕")


# 全局AI服务实例
ai_service = AIService()
