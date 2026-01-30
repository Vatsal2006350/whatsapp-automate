from playwright.sync_api import sync_playwright
import os

def test_browser():
    print("Starting Playwright...")
    try:
        with sync_playwright() as p:
            print("Launching browser...")
            # Try to launch without persistent context first to verify binary
            browser = p.chromium.launch(headless=False)
            print("Browser launched successfully!")
            browser.close()
            print("Browser closed.")
            
            # Now try persistent context
            profile_dir = os.path.abspath("./wa-profile-test")
            print(f"Launching persistent context in {profile_dir}...")
            context = p.chromium.launch_persistent_context(profile_dir, headless=False)
            print("Persistent context launched!")
            page = context.pages[0] if context.pages else context.new_page()
            page.goto("https://example.com")
            print("Navigated to example.com")
            context.close()
            print("Context closed.")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_browser()
