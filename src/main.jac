"""WhatsApp Daily Message Automation - Main Application."""

import os;
import sys;
import schedule;
import time;
import from datetime { datetime }
import from dotenv { load_dotenv }

import from message_generator { generate_full_message }
import from whatsapp_sender { WhatsAppSender }


def get_config() -> dict {
    chat_names_str = os.getenv("CHAT_NAME", "").strip("'\"");
    chat_names: list[str] = [name.strip() for name in chat_names_str.split(",") if name.strip()];
    return {
        "chat_names": chat_names,
        "schedule_hour": int(os.getenv("SCHEDULE_HOUR", "21").strip("'\"")),
        "schedule_minute": int(os.getenv("SCHEDULE_MINUTE", "30").strip("'\"")),
        "headless": os.getenv("HEADLESS", "false").strip("'\"").lower() == "true",
        "wa_profile_dir": os.getenv("WA_PROFILE_DIR", "./wa-profile").strip("'\"")
    };
}


def validate_config(config: dict) -> bool {
    if not os.getenv("OPENAI_API_KEY") {
        print("ERROR: OPENAI_API_KEY is required. Set it in .env file.");
        return False;
    }
    if config["chat_names"].__len__() == 0 {
        print("ERROR: CHAT_NAME is required. Set it in .env file.");
        return False;
    }
    return True;
}


def send_daily_message() {
    config = get_config();
    sep = "=" * 50;
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S");

    print(f"\n{sep}");
    print(f"[{now_str}] Starting daily message...");
    print(sep);

    print("\n1. Generating message with AI...");
    try {
        message = generate_full_message();
        print("Generated message:");
        print("-" * 30);
        print(message);
        print("-" * 30);
    } except Exception as e {
        print(f"ERROR generating message: {e}");
        return;
    }

    print("\n2. Sending to recipients...");
    sender = WhatsAppSender(profile_dir=config["wa_profile_dir"], headless=config["headless"]);

    try {
        if not sender.start() {
            print("Failed to start browser");
            return;
        }

        if not sender.wait_for_login() {
            print("Failed to login");
            return;
        }

        success_count = 0;
        chat_names = config["chat_names"];
        for chat_name in chat_names {
            print(f"\nSending to '{chat_name}'...");
            if sender.send_to_chat(chat_name, message) {
                success_count = success_count + 1;
            }
            sender.page.wait_for_timeout(1000);
        }

        time_str = datetime.now().strftime("%H:%M:%S");
        print(f"\n✓ Sent to {success_count}/{chat_names.__len__()} recipients at {time_str}!");

    } finally {
        sender.close();
    }

    print(f"{sep}\n");
}


def run_scheduler() {
    config = get_config();
    hour = config["schedule_hour"];
    minute = config["schedule_minute"];
    schedule_time = f"{hour:02d}:{minute:02d}";
    recipients = ", ".join(config["chat_names"]);

    print(f"\nScheduling daily message at {schedule_time}...");
    print(f"Recipients: {recipients}");
    print(f"Headless mode: {config['headless']}");

    schedule.every().day.at(schedule_time).do(send_daily_message);

    # Show next run time
    next_run = schedule.next_run();
    if next_run {
        print(f"Next run: {next_run.strftime('%Y-%m-%d %H:%M:%S')}");
    }
    print("\nWaiting... (Press Ctrl+C to stop)\n");

    import sys;
    sys.stdout.flush();

    loop_count = 0;
    while True {
        schedule.run_pending();
        loop_count = loop_count + 1;

        # Print status every 5 minutes (every 10 loops of 30 seconds)
        if loop_count % 10 == 0 {
            now = datetime.now().strftime("%H:%M");
            next_run = schedule.next_run();
            next_str = next_run.strftime("%H:%M") if next_run else "N/A";
            print(f"[{now}] Still waiting... Next run at {next_str}");
            sys.stdout.flush();
        }

        time.sleep(30);
    }
}


with entry {
    print("\n╔══════════════════════════════════════════════════════════╗");
    print("║     WhatsApp Daily Message Automation (Jac + byLLM)      ║");
    print("╚══════════════════════════════════════════════════════════╝\n");

    load_dotenv();
    config = get_config();

    if not validate_config(config) {
        print("\nPlease create a .env file based on .env.example");
        sys.exit(1);
    }

    try {
        run_scheduler();
    } except KeyboardInterrupt {
        print("\nScheduler stopped.");
    }
}
