"""Message Generator using byLLM with OpenAI."""

import os;
import random;
import from byllm.lib { Model }

# Initialize the LLM model
glob llm = Model(model_name="gpt-4o-mini");

glob THEMES: list[str] = ["friendship and loyalty", "perseverance through hardship", "self-improvement and growth", "gratitude and appreciation", "courage and taking risks", "time and its value", "positive mindset", "learning from mistakes", "success and consistency", "inner peace and wisdom", "relationships and trust", "hope and optimism"];

glob HEADER: str = "Thought for the day....";
glob FOOTER: str = "Good Morning!!!😃Jai Shree Krishna🙏";
glob NL: str = "\n";


"""Generate a unique inspirational 'Thought for the day' message.
The thought should be 2-4 sentences maximum, inspirational and meaningful.
About the given theme. Similar to motivational quotes about life and wisdom.
You may talk about God, and just doing good in your life regardless of what others do.
Fresh and unique, not a famous quote. Do NOT use weird words or too fluffy, it should be fairly natrual.
The message should really hit, should be meaningful. Below are some samples of the other messages, just for reference but you must innovate:

Return ONLY the thought text, nothing else."""
def generate_thought(theme: str = "life wisdom") -> str by llm();


def format_message(thought: str) -> str {
    return f"{HEADER}{NL}{NL}{thought}{NL}{NL}{FOOTER}";
}


def generate_full_message() -> str {
    theme = random.choice(THEMES);
    thought = generate_thought(theme=theme);
    return format_message(thought);
}
