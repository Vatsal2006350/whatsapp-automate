"""WhatsApp Web Login Helper.

Run this script once to scan the QR code and save the session.
After successful login, the session is saved and subsequent runs
won't require QR scanning.
"""

import os;
import from pathlib { Path }
import from dotenv { load_dotenv }
import from playwright.sync_api { sync_playwright }


def login_to_whatsapp() {
    load_dotenv();

    profile_dir = os.getenv("WA_PROFILE_DIR", "./wa-profile");
    profile_path = str(Path(profile_dir).absolute());

    Path(profile_path).mkdir(parents=True, exist_ok=True);

    print("\n╔══════════════════════════════════════════════════════════╗");
    print("║           WhatsApp Web Login Helper                       ║");
    print("╚══════════════════════════════════════════════════════════╝\n");
    print("This will open WhatsApp Web in a browser.\n");
    print("Instructions:");
    print("1. A browser window will open with WhatsApp Web");
    print("2. Scan the QR code with your phone's WhatsApp app");
    print("3. Once logged in, the session will be saved");
    print("4. Press Enter in this terminal when done to close\n");
    print(f"Your session will be saved to: {profile_path}\n");
    print("Starting browser...\n");

    playwright = sync_playwright().start();

    context = playwright.chromium.launch_persistent_context(profile_path, headless=False, args=["--disable-blink-features=AutomationControlled"]);

    if context.pages.__len__() > 0 {
        page = context.pages[0];
    } else {
        page = context.new_page();
    }

    page.goto("https://web.whatsapp.com/", wait_until="domcontentloaded");

    print("Browser opened. Please scan the QR code with your phone.");
    print("Waiting for login...\n");

    try {
        page.wait_for_selector('div[aria-label="Search input textbox"]', timeout=300000);
        print("✓ Login successful! Session saved.\n");
        print("You can now close this terminal. The session is saved.");
        print("Future runs will use this saved session.\n");
        input("Press Enter to close the browser...");
    } except Exception as e {
        print(f"Login timeout or error: {e}");
        print("You may need to try again.");
    }

    context.close();
    playwright.stop();

    print("Browser closed. Goodbye!");
}


with entry {
    login_to_whatsapp();
}
