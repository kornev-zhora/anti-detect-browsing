How It Works

1. Authenticates with Multilogin cloud API (api.multilogin.com/user/signin) to get a bearer token
2. Starts a quick profile via POST /api/v3/profile/quick with Selenium automation enabled and default masking flags
3. Connects to the browser via Selenium WebDriver on the returned port
4. Navigates to https://www.scrapingcourse.com/login/csrf
5. Fills in email (admin@example.com) and password (password)
6. Takes 3 screenshots: login page, filled form, after login - saved to storage/app/screenshots/
7. Closes the browser and stops the profile

