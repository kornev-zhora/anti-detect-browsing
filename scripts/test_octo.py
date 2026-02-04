#!/usr/bin/env python3
"""
Octo Browser API - Full working test with authentication + Selenium
"""

import os
import time
import requests
from dotenv import load_dotenv
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

# --------------------------------------------------
# ENV
# --------------------------------------------------
load_dotenv()

OCTO_API = os.getenv("OCTO_API_URL", "http://localhost:58888")
OCTO_EMAIL = os.getenv("OCTO_EMAIL")
OCTO_PASSWORD = os.getenv("OCTO_PASSWORD")

RESULTS_DIR = "results"
os.makedirs(RESULTS_DIR, exist_ok=True)


# --------------------------------------------------
# OCTO API CLIENT
# --------------------------------------------------
class OctoAPI:
    def __init__(self):
        self.api_url = OCTO_API.rstrip("/")
        self.token = None

    def login(self) -> bool:
        print("🔐 Logging in to Octo Browser API...")

        if not OCTO_EMAIL or not OCTO_PASSWORD:
            print("❌ OCTO_EMAIL / OCTO_PASSWORD not set")
            return False

        try:
            r = requests.post(
                f"{self.api_url}/api/v1/auth/login",
                json={
                    "email": OCTO_EMAIL,
                    "password": OCTO_PASSWORD,
                },
                timeout=15,
            )
        except requests.exceptions.ConnectionError:
            print("❌ Cannot connect to Octo API")
            return False

        if r.status_code != 200:
            print(f"❌ Login failed: {r.status_code}")
            print(r.text)
            return False

        self.token = r.json().get("token")
        print("✅ Logged in successfully")
        return True

    def headers(self):
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }

    def list_profiles(self):
        print("📋 Listing profiles...")
        r = requests.get(
            f"{self.api_url}/api/v1/profiles",
            headers=self.headers(),
        )
        if r.status_code == 200:
            profiles = r.json()
            print(f"✅ Found {len(profiles)} profiles")
            return profiles
        print("⚠️ Failed to list profiles")
        return []

    def create_profile(self, name: str) -> str | None:
        print(f"🔨 Creating profile: {name}")

        payload = {
            "title": name,
            "tags": ["automation", "selenium"],
            "start_page": "https://www.whatismybrowser.com/",
            "fingerprint": {
                "os": "win",
                "screen": {"width": 1920, "height": 1080},
            },
        }

        r = requests.post(
            f"{self.api_url}/api/v1/profiles",
            headers=self.headers(),
            json=payload,
        )

        if r.status_code != 200:
            print("❌ Failed to create profile")
            print(r.text)
            return None

        uuid = r.json().get("uuid")
        print(f"✅ Profile created: {uuid}")
        return uuid

    def start_profile(self, uuid: str, headless: bool = True) -> int | None:
        print(f"🚀 Starting profile {uuid}")

        r = requests.post(
            f"{self.api_url}/api/v1/profiles/start",
            headers=self.headers(),
            json={
                "uuid": uuid,
                "headless": headless,
                "debug_port": True,
            },
        )

        if r.status_code != 200:
            print("❌ Failed to start profile")
            print(r.text)
            return None

        data = r.json()
        debug_port = (
            data.get("debug_port")
            or data.get("automation", {}).get("port")
        )

        if not debug_port:
            print("❌ Debug port not returned")
            print(data)
            return None

        print(f"✅ Profile started on port {debug_port}")
        return debug_port

    def stop_profile(self, uuid: str):
        print(f"🛑 Stopping profile {uuid}")
        requests.post(
            f"{self.api_url}/api/v1/profiles/stop",
            headers=self.headers(),
            json={"uuid": uuid},
        )

    def delete_profile(self, uuid: str):
        print(f"🗑️ Deleting profile {uuid}")
        requests.delete(
            f"{self.api_url}/api/v1/profiles/{uuid}",
            headers=self.headers(),
        )


# --------------------------------------------------
# SELENIUM CONNECTOR
# --------------------------------------------------
def connect_selenium(debug_port: int):
    print(f"🔗 Connecting Selenium to localhost:{debug_port}")

    options = Options()
    options.add_experimental_option(
        "debuggerAddress", f"localhost:{debug_port}"
    )

    try:
        driver = webdriver.Chrome(options=options)
        print("✅ Selenium connected")
        return driver
    except Exception as e:
        print("❌ Selenium connection failed")
        print(e)
        return None


# --------------------------------------------------
# MAIN
# --------------------------------------------------
def main():
    print("=" * 60)
    print("Octo Browser API + Selenium FULL TEST")
    print("=" * 60)

    octo = OctoAPI()

    if not octo.login():
        return

    octo.list_profiles()

    uuid = octo.create_profile("Octo Selenium Test")
    if not uuid:
        return

    try:
        debug_port = octo.start_profile(uuid, headless=True)
        if not debug_port:
            return

        driver = connect_selenium(debug_port)
        if not driver:
            return

        print("🧪 Running test...")
        time.sleep(6)

        print("   Title:", driver.title)
        print("   URL:", driver.current_url)

        screenshot_path = f"{RESULTS_DIR}/octo_test.png"
        driver.save_screenshot(screenshot_path)
        print(f"📸 Screenshot saved: {screenshot_path}")

        time.sleep(5)

        driver.quit()
        octo.stop_profile(uuid)

    finally:
        octo.delete_profile(uuid)

    print("✅ Test finished successfully")


if __name__ == "__main__":
    main()
