"""WhatsApp Web Sender using Playwright."""

import os;
import from pathlib { Path }
import from playwright.sync_api { sync_playwright }


obj WhatsAppSender {
    """Handles WhatsApp Web automation using Playwright."""

    has profile_dir: str = "./wa-profile";
    has headless: bool = False;
    has context: object = None;
    has page: object = None;
    has playwright_instance: object = None;

    def start() -> bool {
        try {
            profile_path = str(Path(self.profile_dir).absolute());
            Path(profile_path).mkdir(parents=True, exist_ok=True);
            self.playwright_instance = sync_playwright().start();
            self.context = self.playwright_instance.chromium.launch_persistent_context(profile_path, headless=self.headless, args=["--disable-blink-features=AutomationControlled"]);
            if len(self.context.pages) > 0 {
                self.page = self.context.pages[0];
            } else {
                self.page = self.context.new_page();
            }
            self.page.goto("https://web.whatsapp.com/", wait_until="domcontentloaded");
            return True;
        } except Exception as e {
            print(f"ERROR starting browser: {e}");
            return False;
        }
    }

    def wait_for_login(timeout_seconds: int = 180) -> bool {
        print("Waiting for WhatsApp Web to load...");
        print("If you see a QR code, scan it with your phone.");
        try {
            self.page.wait_for_selector('div[aria-label="Search input textbox"]', timeout=timeout_seconds * 1000);
            print("WhatsApp Web loaded successfully!");
            return True;
        } except Exception as e {
            print(f"ERROR waiting for login: {e}");
            return False;
        }
    }

    def find_and_open_chat(chat_name: str) -> bool {
        try {
            print(f"  Searching for chat: '{chat_name}'");

            # Press Escape to close any open chat/menu first
            self.page.keyboard.press("Escape");
            self.page.wait_for_timeout(500);

            # Find and click the search box
            search_box = self.page.locator('div[aria-label="Search input textbox"]');
            search_box.wait_for(timeout=10000);
            search_box.click();
            self.page.wait_for_timeout(500);

            # Clear existing text and type new search
            search_box.fill("");
            self.page.wait_for_timeout(300);
            search_box.fill(chat_name);
            print(f"  Typed '{chat_name}' in search box");
            self.page.wait_for_timeout(2000);

            # Try to find and click the chat in search results
            # Look for the chat row that contains our chat name
            selectors_to_try: list[str] = [
                f'span[title="{chat_name}"]',
                f'div[role="listitem"] span[title="{chat_name}"]',
                f'div[data-testid="cell-frame-container"]:has-text("{chat_name}")',
                f'div[role="row"]:has-text("{chat_name}")',
                f'div[role="listitem"]:has-text("{chat_name}")'
            ];

            for selector in selectors_to_try {
                try {
                    print(f"  Trying selector: {selector}");
                    chat_element = self.page.locator(selector).first;
                    chat_element.wait_for(timeout=3000);
                    chat_element.click();
                    self.page.wait_for_timeout(2000);

                    # Verify chat opened by checking for message input
                    msg_input = self.page.locator('div[contenteditable="true"][data-tab="10"], footer div[contenteditable="true"]').first;
                    try {
                        msg_input.wait_for(timeout=3000);
                        print(f"  ✓ Opened chat: {chat_name}");
                        return True;
                    } except Exception {
                        print(f"  Chat clicked but message box not found, trying next selector...");
                        self.page.keyboard.press("Escape");
                        self.page.wait_for_timeout(500);
                        search_box.click();
                        self.page.wait_for_timeout(300);
                        continue;
                    }
                } except Exception {
                    continue;
                }
            }

            # Last resort: use keyboard navigation
            print(f"  Trying keyboard navigation...");
            self.page.keyboard.press("ArrowDown");
            self.page.wait_for_timeout(500);
            self.page.keyboard.press("Enter");
            self.page.wait_for_timeout(2000);

            # Check if chat opened
            msg_input = self.page.locator('div[contenteditable="true"][data-tab="10"], footer div[contenteditable="true"]').first;
            try {
                msg_input.wait_for(timeout=3000);
                print(f"  ✓ Opened chat via keyboard: {chat_name}");
                return True;
            } except Exception {
                print(f"  ✗ Could not open chat: {chat_name}");
                return False;
            }

        } except Exception as e {
            print(f"  ✗ ERROR finding chat '{chat_name}': {e}");
            return False;
        }
    }

    def send_message(message: str) -> bool {
        try {
            # Wait for chat to fully load
            self.page.wait_for_timeout(2000);

            # Try multiple selectors for message box
            message_box = None;
            selectors: list[str] = [
                'div[contenteditable="true"][data-tab="10"]',
                'footer div[contenteditable="true"]',
                'div[aria-label="Type a message"]',
                'div[title="Type a message"]'
            ];

            for selector in selectors {
                try {
                    box = self.page.locator(selector).first;
                    box.wait_for(timeout=3000);
                    message_box = box;
                    print(f"Found message box with: {selector}");
                    break;
                } except Exception {
                    continue;
                }
            }

            if not message_box {
                print("ERROR: Could not find message input box");
                return False;
            }

            message_box.click();
            self.page.wait_for_timeout(300);

            lines: list[str] = message.split("\n");
            num_lines: int = lines.__len__();
            for i in range(num_lines) {
                message_box.type(lines[i], delay=10);
                if i < num_lines - 1 {
                    self.page.keyboard.press("Shift+Enter");
                }
            }
            self.page.wait_for_timeout(500);
            self.page.keyboard.press("Enter");
            self.page.wait_for_timeout(2000);
            print("Message sent successfully!");
            return True;
        } except Exception as e {
            print(f"ERROR sending message: {e}");
            return False;
        }
    }

    def send_to_chat(chat_name: str, message: str) -> bool {
        if not self.find_and_open_chat(chat_name) {
            return False;
        }
        return self.send_message(message);
    }

    def close() {
        try {
            if self.context {
                self.context.close();
            }
            if self.playwright_instance {
                self.playwright_instance.stop();
            }
            print("Browser closed.");
        } except Exception as e {
            print(f"Error closing browser: {e}");
        }
    }
}


def send_whatsapp_message(chat_name: str, message: str, profile_dir: str = "./wa-profile", headless: bool = False) -> bool {
    sender = WhatsAppSender(profile_dir=profile_dir, headless=headless);
    try {
        if not sender.start() {
            return False;
        }
        if not sender.wait_for_login() {
            return False;
        }
        return sender.send_to_chat(chat_name, message);
    } finally {
        sender.close();
    }
}
