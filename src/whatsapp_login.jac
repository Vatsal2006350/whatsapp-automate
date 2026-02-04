# WhatsApp Login Manager - handles QR code capture and session management

import os;
import base64;
import from pathlib { Path }
import from playwright.sync_api { sync_playwright }


obj WhatsAppLoginManager {
    # Manages WhatsApp Web login session with QR code capture

    has profile_dir: str = "./wa-profile";
    has headless: bool = True;
    has browser: object = None;
    has page: object = None;
    has playwright_instance: object = None;
    has is_logged_in: bool = False;
    has qr_screenshot_path: str = "";

    def get_screenshot_dir() -> str {
        dir_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "qr");
        os.makedirs(dir_path, exist_ok=True);
        return dir_path;
    }

    def start() -> dict {
        # Start a WhatsApp Web session and prepare for QR capture
        # Close any existing session
        if self.browser {
            self.close();
        }

        try {
            self.playwright_instance = sync_playwright().start();

            abs_profile = str(Path(self.profile_dir).absolute());
            Path(abs_profile).mkdir(parents=True, exist_ok=True);

            self.browser = self.playwright_instance.chromium.launch_persistent_context(
                abs_profile,
                headless=self.headless,
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                args=[
                    "--no-sandbox",
                    "--disable-setuid-sandbox",
                    "--disable-blink-features=AutomationControlled",
                    "--disable-dev-shm-usage",
                    "--disable-infobars",
                    "--disable-background-timer-throttling",
                    "--disable-popup-blocking",
                    "--disable-backgrounding-occluded-windows",
                    "--disable-renderer-backgrounding",
                    "--disable-window-activation",
                    "--disable-focus-on-load",
                    "--no-first-run",
                    "--no-default-browser-check",
                    "--window-size=1920,1080"
                ],
                viewport={"width": 1920, "height": 1080},
                ignore_https_errors=True
            );

            if len(self.browser.pages) > 0 {
                self.page = self.browser.pages[0];
            } else {
                self.page = self.browser.new_page();
            }

            # Anti-detection: Remove webdriver property before navigation
            self.page.add_init_script("""
                Object.defineProperty(navigator, 'webdriver', {
                    get: () => undefined
                });
                Object.defineProperty(navigator, 'plugins', {
                    get: () => [1, 2, 3, 4, 5]
                });
                Object.defineProperty(navigator, 'languages', {
                    get: () => ['en-US', 'en']
                });
                window.chrome = { runtime: {} };
            """);

            self.page.goto("https://web.whatsapp.com", wait_until="domcontentloaded");

            # Wait for page to fully load - WhatsApp takes time to render QR
            print("Waiting for WhatsApp page to load...");
            self.page.wait_for_timeout(5000);

            # Wait specifically for the QR code canvas to appear and be visible
            try {
                print("Looking for QR code element...");
                qr_wait_selectors = [
                    'canvas[aria-label="Scan this QR code to link a device!"]',
                    'canvas[aria-label="Scan me!"]',
                    'div[data-testid="qrcode"] canvas',
                    'canvas'
                ];
                for selector in qr_wait_selectors {
                    try {
                        element = self.page.locator(selector).first;
                        element.wait_for(state="visible", timeout=30000);
                        print(f"Found visible element: {selector}");
                        # Extra wait for canvas to actually render content
                        self.page.wait_for_timeout(2000);
                        break;
                    } except Exception {
                        continue;
                    }
                }
            } except Exception as e {
                print(f"QR wait error: {e}");
            }

            # Check if already logged in
            if self.check_logged_in() {
                self.is_logged_in = True;
                return {"success": True, "logged_in": True, "message": "Already logged in"};
            }

            # Not logged in, capture QR
            self.is_logged_in = False;
            self.capture_qr();

            return {"success": True, "logged_in": False, "message": "QR code ready"};

        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def check_logged_in() -> bool {
        # Check if WhatsApp is logged in by looking for the chat list
        if not self.page {
            return False;
        }

        try {
            # Look for elements that only appear when logged in
            chat_list = self.page.locator('div[aria-label="Chat list"], div[data-testid="chat-list"]').first;
            chat_list.wait_for(timeout=2000);
            self.is_logged_in = True;
            return True;
        } except Exception {
            # Also check for the search box which appears when logged in
            try {
                search = self.page.locator('div[aria-label="Search input textbox"]').first;
                search.wait_for(timeout=1000);
                self.is_logged_in = True;
                return True;
            } except Exception {
                self.is_logged_in = False;
                return False;
            }
        }
    }

    def capture_qr() -> bool {
        # Capture a screenshot of the QR code area
        if not self.page {
            return False;
        }

        try {
            screenshot_dir = self.get_screenshot_dir();
            self.qr_screenshot_path = os.path.join(screenshot_dir, "qr_code.png");

            # Try to find the QR code canvas
            qr_selectors: list[str] = [
                'canvas[aria-label="Scan this QR code to link a device!"]',
                'canvas[aria-label="Scan me!"]',
                'div[data-testid="qrcode"] canvas',
                'div._akau canvas',
                'canvas'
            ];

            for selector in qr_selectors {
                try {
                    print(f"Trying selector: {selector}");
                    qr_element = self.page.locator(selector).first;
                    qr_element.wait_for(timeout=5000);
                    qr_element.screenshot(path=self.qr_screenshot_path);
                    print(f"QR captured with selector: {selector}");
                    return True;
                } except Exception as e {
                    print(f"Selector {selector} failed: {e}");
                    continue;
                }
            }

            # Fallback: screenshot the whole page
            print("All selectors failed, taking full page screenshot");
            self.page.screenshot(path=self.qr_screenshot_path, timeout=60000);
            print(f"Full page screenshot saved to: {self.qr_screenshot_path}");
            return True;

        } except Exception as e {
            print(f"Error capturing QR: {e}");
            import traceback;
            traceback.print_exc();
            return False;
        }
    }

    def get_qr_base64() -> str {
        # Get the QR code as base64 string
        if not self.qr_screenshot_path or not os.path.exists(self.qr_screenshot_path) {
            return "";
        }

        try {
            f = open(self.qr_screenshot_path, "rb");
            data = f.read();
            f.close();
            return base64.b64encode(data).decode("utf-8");
        } except Exception {
            return "";
        }
    }

    def refresh_qr() -> dict {
        # Refresh the QR code screenshot
        if not self.page {
            return {"success": False, "error": "No active session"};
        }

        # First check if logged in
        if self.check_logged_in() {
            return {"success": True, "logged_in": True};
        }

        # Not logged in, refresh QR
        if self.capture_qr() {
            qr_data = self.get_qr_base64();
            return {"success": True, "logged_in": False, "qr": qr_data};
        }

        return {"success": False, "error": "Could not capture QR"};
    }

    def get_status() -> dict {
        # Get current login status
        if not self.browser or not self.page {
            return {"active": False, "logged_in": False};
        }

        logged_in = self.check_logged_in();
        return {"active": True, "logged_in": logged_in};
    }

    def close() {
        # Close the login session
        try {
            if self.page {
                self.page.close();
            }
        } except Exception as e {
            print(f"Error closing page: {e}");
        }

        try {
            if self.browser {
                self.browser.close();
            }
        } except Exception as e {
            print(f"Error closing browser: {e}");
        }

        try {
            if self.playwright_instance {
                self.playwright_instance.stop();
            }
        } except Exception as e {
            print(f"Error stopping playwright: {e}");
        }

        self.browser = None;
        self.page = None;
        self.playwright_instance = None;
        self.is_logged_in = False;
    }
}


# Global login manager instance
glob login_manager: object = None;


def start_login_session(profile_dir: str = "./wa-profile", headless: bool = True) -> dict {
    global login_manager;
    login_manager = WhatsAppLoginManager(profile_dir=profile_dir, headless=headless);
    return login_manager.start();
}


def refresh_qr() -> dict {
    global login_manager;
    if not login_manager {
        return {"success": False, "error": "No active session"};
    }
    return login_manager.refresh_qr();
}


def get_login_status() -> dict {
    global login_manager;
    if not login_manager {
        return {"active": False, "logged_in": False};
    }
    return login_manager.get_status();
}


def get_qr_base64() -> str {
    global login_manager;
    if not login_manager {
        return "";
    }
    return login_manager.get_qr_base64();
}


def close_login_session() {
    global login_manager;
    if login_manager {
        login_manager.close();
        login_manager = None;
    }
}
