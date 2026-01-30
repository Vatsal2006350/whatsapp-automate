"""Send a message immediately (for testing)."""

import os;
import from dotenv { load_dotenv }
import from src.message_generator { generate_full_message }
import from src.whatsapp_sender { send_whatsapp_message, WhatsAppSender }

with entry {
    load_dotenv();

    chat_names_str = os.getenv("CHAT_NAME", "").strip("'\"");
    print(f"DEBUG: Raw CHAT_NAME from .env = '{chat_names_str}'");

    chat_names: list[str] = [name.strip() for name in chat_names_str.split(",") if name.strip()];

    print(f"DEBUG: Parsed {chat_names.__len__()} recipients:");
    idx = 1;
    for name in chat_names {
        print(f"  {idx}. '{name}'");
        idx = idx + 1;
    }

    profile_dir = os.getenv("WA_PROFILE_DIR", "./wa-profile").strip("'\"");
    headless = os.getenv("HEADLESS", "false").strip("'\"").lower() == "true";
    print(f"DEBUG: headless = {headless}");

    if chat_names.__len__() == 0 {
        print("ERROR: No chat names configured in CHAT_NAME");
    }

    print("\nGenerating message...\n");
    message = generate_full_message();
    print("Message:");
    print("-" * 40);
    print(message);
    print("-" * 40);

    # Send to all recipients
    sender = WhatsAppSender(profile_dir=profile_dir, headless=headless);

    try {
        if not sender.start() {
            print("Failed to start browser");
        }

        if not sender.wait_for_login() {
            print("Failed to login");
        }

        success_count = 0;
        total = chat_names.__len__();
        current = 0;

        for chat_name in chat_names {
            current = current + 1;
            print(f"\n[{current}/{total}] Attempting to send to: '{chat_name}'");
            result = sender.send_to_chat(chat_name, message);
            if result {
                print(f"  ✓ SUCCESS: Sent to '{chat_name}'");
                success_count = success_count + 1;
            } else {
                print(f"  ✗ FAILED: Could not send to '{chat_name}'");
            }
            sender.page.wait_for_timeout(1500);
        }

        print(f"\n{'='*40}");
        print(f"SUMMARY: Sent to {success_count}/{total} recipients");
        print(f"{'='*40}");

    } finally {
        sender.close();
    }
}
