import random;
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

glob THEMES: list[str] = [
    "friendship and loyalty",
    "perseverance through hardship",
    "self-improvement and growth",
    "gratitude and appreciation",
    "courage and taking risks",
    "time and its value",
    "positive mindset",
    "learning from mistakes",
    "success and consistency",
    "inner peace and wisdom",
    "relationships and trust",
    "hope and optimism"
];

glob HEADER: str = "Thought for the day....";
glob FOOTER: str = "Good Morning!!!😃Jai Shree Krishna🙏";

sem generate_daily_inspirational_thought = "Create a fresh, unique 2-4 sentence thought. Keep it simple yet profound, natural and meaningful - avoid fluffy or weird words. Similar to motivational quotes about life wisdom.";
def generate_daily_inspirational_thought(theme: str) -> str by llm(temperature=0.9);

def format_message(thought: str) -> str {
    return f"{HEADER}\n\n{thought}\n\n{FOOTER}";
}

def generate_full_message() -> str {
    theme = random.choice(THEMES);
    thought = generate_daily_inspirational_thought(theme=theme);
    return format_message(thought);
}
