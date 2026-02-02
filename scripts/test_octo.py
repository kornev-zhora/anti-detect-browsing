#!/usr/bin/env python3
"""
Octo Browser API - Test with Authentication
"""

import requests
import time
import os
from dotenv import load_dotenv
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

load_dotenv()

OCTO_API = os.getenv('OCTO_API_URL', 'http://localhost:58888')
OCTO_EMAIL = os.getenv('OCTO_EMAIL')
OCTO_PASSWORD = os.getenv('OCTO_PASSWORD')

class OctoAPI:
    def __init__(self):
        self.api_url = OCTO_API
        self.token = None

    def login(self):
        """Authenticate with Octo API"""
        print("🔐 Logging in to Octo Browser...")

        if not OCTO_EMAIL or not OCTO_PASSWORD:
            print("❌ OCTO_EMAIL or OCTO_PASSWORD not set in .env")
            return False

        try:
            response = requests.post(
                f"{self.api_url}/api/auth/login",
                json={
                    "email": OCTO_EMAIL,
                    "password": OCTO_PASSWORD
                }
            )

            if response.status_code == 200:
                data = response.json()
                self.token = data.get('token')
                print(f"✅ Logged in successfully!")
                return True
            else:
                print(f"❌ Login failed: {response.status_code}")
                print(response.text)
                return False

        except requests.exceptions.ConnectionError:
            print("❌ Cannot connect to Octo API")
            print("   Start with: make octo-start")
            return False

    def get_headers(self):
        """Get headers with auth token"""
        if not self.token:
            return {}
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }

    def list_profiles(self):
        """List all profiles"""
        print("\n📋 Fetching profiles...")

        response = requests.get(
            f"{self.api_url}/api/v1/profiles",
            headers=self.get_headers()
        )

        if response.status_code == 200:
            profiles = response.json()
            print(f"✅ Found {len(profiles)} profiles")
            return profiles
        else:
            print(f"❌ Failed: {response.status_code}")
            return []

    def create_profile(self, name):
        """Create new profile"""
        print(f"\n🔨 Creating profile: {name}")

        payload = {
            "title": name,
            "tags": ["testing", "automation"],
            "fingerprint": {
                "os": "win",
                "screen": {
                    "width": 1920,
                    "height": 1080
                }
            },
            "start_page": "https://www.whatismybrowser.com/"
        }

        response = requests.post(
            f"{self.api_url}/api/v1/profiles",
            headers=self.get_headers(),
            json=payload
        )

        if response.status_code == 200:
            profile = response.json()
            uuid = profile.get('uuid')
            print(f"✅ Profile created: {uuid}")
            return uuid
        else:
            print(f"❌ Failed: {response.status_code}")
            print(response.text)
            return None

    def start_profile(self, uuid, headless=True):
        """Start profile"""
        print(f"\n🚀 Starting profile: {uuid}")

        payload = {
            "uuid": uuid,
            "headless": headless,
            "debug_port": True
        }

        response = requests.post(
            f"{self.api_url}/api/profiles/start",
            headers=self.get_headers(),
            json=payload
        )

        if response.status_code == 200:
            data = response.json()
            debug_port = data.get('debug_port')
            print(f"✅ Profile started!")
            print(f"   Debug port: {debug_port}")
            return debug_port
        else:
            print(f"❌ Failed: {response.status_code}")
            print(response.text)
            return None

    def stop_profile(self, uuid):
        """Stop profile"""
        print(f"\n🛑 Stopping profile: {uuid}")

        response = requests.post(
            f"{self.api_url}/api/profiles/stop",
            headers=self.get_headers(),
            json={"uuid": uuid}
        )

        if response.status_code == 200:
            print("✅ Profile stopped")
            return True
        else:
            print(f"⚠️  Stop failed: {response.status_code}")
            return False

    def delete_profile(self, uuid):
        """Delete profile"""
        print(f"\n🗑️  Deleting profile: {uuid}")

        response = requests.delete(
            f"{self.api_url}/api/v1/profiles/{uuid}",
            headers=self.get_headers()
        )

        if response.status_code == 200:
            print("✅ Profile deleted")
            return True
        else:
            print(f"⚠️  Delete failed: {response.status_code}")
            return False

def connect_selenium(debug_port):
    """Connect Selenium to Octo profile"""
    print(f"\n🔗 Connecting Selenium to port {debug_port}...")

    options = Options()
    options.add_experimental_option('debuggerAddress', f'localhost:{debug_port}')

    try:
        driver = webdriver.Chrome(options=options)
        print("✅ Selenium connected!")
        return driver
    except Exception as e:
        print(f"❌ Selenium error: {e}")
        return None

def main():
    print("=" * 60)
    print("Octo Browser - Full API Test with Authentication")
    print("=" * 60)

    # Initialize API client
    octo = OctoAPI()

    # Login
    if not octo.login():
        exit(1)

    # List existing profiles
    profiles = octo.list_profiles()

    # Create test profile
    profile_uuid = octo.create_profile("Test Profile - Memory Benchmark")
    if not profile_uuid:
        exit(1)

    try:
        # Start profile
        debug_port = octo.start_profile(profile_uuid, headless=True)
        if not debug_port:
            exit(1)

        # Connect Selenium
        driver = connect_selenium(debug_port)
        if not driver:
            exit(1)

        # Test automation
        print("\n🧪 Testing automation...")
        time.sleep(5)  # Wait for page load

        print(f"   Title: {driver.title}")
        print(f"   URL: {driver.current_url}")

        # Screenshot
        driver.save_screenshot("results/octo_test.png")
        print("   Screenshot: results/octo_test.png")

        # Keep running
        print("\n⏳ Browser running for 10 seconds...")
        time.sleep(10)

        # Cleanup
        driver.quit()
        octo.stop_profile(profile_uuid)

    finally:
        # Delete test profile
        octo.delete_profile(profile_uuid)

    print("\n✅ Test complete!")
    print("\n📊 Summary:")
    print("   - Authenticated with Octo API")
    print("   - Created and started profile")
    print("   - Selenium automation successful")
    print("   - Profile cleaned up")

if __name__ == "__main__":
    main()