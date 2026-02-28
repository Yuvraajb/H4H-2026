"""
LLM Service - Workstream C
Handles communication with OpenAI or Anthropic LLM APIs.
"""
import os
from typing import Dict, Any, Optional

# Mock implementation - Workstream C will implement real LLM integration
class LLMService:
    def __init__(self):
        self.provider = os.getenv("LLM_PROVIDER", "openai")
        self.model = os.getenv("LLM_MODEL", "gpt-4o")
        self.api_key = os.getenv("OPENAI_API_KEY") or os.getenv("ANTHROPIC_API_KEY")

    async def generate_response(
        self,
        user_message: str,
        context: Optional[Dict[str, Any]] = None,
        mode: str = "live"
    ) -> Dict[str, Any]:
        """
        Generate AI response based on user message and context.
        
        Args:
            user_message: The user's spoken text
            context: Optional session context (transcript, metadata, etc.)
            mode: "live" or "training"
        
        Returns:
            Dictionary with "text" and "metadata" keys
        """
        # Mock response - Workstream C will implement real LLM call
        print(f"[LLM Service] Mock response for: {user_message}")
        
        return {
            "text": "I understand. Let me guide you through this step by step. First, ensure the area is safe.",
            "metadata": {
                "step": 1,
                "urgency": "medium",
                "image_query": "first aid safety check",
                "category": "safety",
                "display_text": "Step 1: Ensure Safety",
            },
        }

    def get_system_prompt(self, mode: str = "live", scenario: Optional[str] = None) -> str:
        """
        Get the system prompt for the LLM based on mode and scenario.
        """
        if mode == "training":
            return f"""You are a training assistant for first responders. 
            The user is practicing scenario: {scenario or 'general first aid'}.
            Provide step-by-step guidance and score their performance."""
        
        return """You are a calm, professional first aid assistant. 
        Guide users through emergency situations step-by-step.
        Always prioritize safety and provide clear, actionable instructions.
        Detect urgency levels and suggest relevant instructional images when helpful."""
