"""Test message generation only."""

import os;
import from dotenv { load_dotenv }

import from src.message_generator { generate_full_message, generate_thought, THEMES }


with entry {
    load_dotenv();

    api_key = os.getenv("GEMINI_API_KEY", "");
    if not api_key {
        print("ERROR: GEMINI_API_KEY not set in .env file");
    }

    print("Testing message generation with Gemini...\n");

    message = generate_full_message();

    print("=" * 50);
    print(message);
    print("=" * 50);
}
