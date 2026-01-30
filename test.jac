"""Quick test for message generation."""

import from dotenv { load_dotenv }
import from src.message_generator { generate_full_message }

with entry {
    load_dotenv();

    print("Testing message generation...\n");

    message = generate_full_message();

    print("=" * 50);
    print(message);
    print("=" * 50);
}
