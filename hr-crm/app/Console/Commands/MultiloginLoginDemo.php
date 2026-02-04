<?php

namespace App\Console\Commands;

use App\Services\MultiloginClient;
use Facebook\WebDriver\Remote\DesiredCapabilities;
use Facebook\WebDriver\Remote\RemoteWebDriver;
use Facebook\WebDriver\WebDriverBy;
use Facebook\WebDriver\WebDriverExpectedCondition;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Throwable;

class MultiloginLoginDemo extends Command
{
    protected $signature = 'app:multilogin-login-demo
        {--headless : Run the browser in headless mode}
        {--browser=mimic : Browser type (mimic or stealthfox)}
        {--os=linux : OS type (linux, windows, macos)}';

    protected $description = 'Start a Multilogin quick profile, login to scrapingcourse.com CSRF demo, and take screenshots';

    public function handle(): int
    {
        $client = new MultiloginClient(
            launcherUrl: config('multilogin.launcher_url'),
            seleniumHost: config('multilogin.selenium_host'),
            signinUrl: config('multilogin.signin_url'),
            username: config('multilogin.username'),
            password: config('multilogin.password'),
        );

        // Step 1: Authenticate if credentials are available
        if (config('multilogin.username') && config('multilogin.password')) {
            $this->info('Authenticating with Multilogin...');

            try {
                $client->authenticate();
                $this->info('Authentication successful.');
            } catch (Throwable $e) {
                $this->error("Authentication failed: {$e->getMessage()}");

                return self::FAILURE;
            }
        } else {
            $this->warn('No Multilogin credentials configured. Attempting without auth token.');
        }

        // Step 2: Start a quick profile
        $this->info('Starting quick browser profile...');

        try {
            $profileData = $client->startQuickProfile(
                headless: (bool) $this->option('headless'),
                browserType: $this->option('browser'),
                osType: $this->option('os'),
            );
        } catch (Throwable $e) {
            $this->error("Failed to start profile: {$e->getMessage()}");

            return self::FAILURE;
        }

        $profileId = $profileData['id'];
        $port = $profileData['port'];

        $this->info("Profile started: {$profileId}");
        $this->info("Browser: {$profileData['browser_type']} v{$profileData['core_version']}");
        $this->info("WebDriver port: {$port}");

        // Step 3: Connect via Selenium WebDriver
        $seleniumUrl = $client->getSeleniumUrl($port);
        $this->info("Connecting to WebDriver at {$seleniumUrl}...");

        $this->info('Waiting for browser to initialize...');
        sleep(5);

        try {
            $driver = RemoteWebDriver::create(
                $seleniumUrl,
                DesiredCapabilities::chrome(),
                60_000,
                60_000,
            );
        } catch (Throwable $e) {
            $this->error("Failed to connect to WebDriver: {$e->getMessage()}");
            $client->stopProfile($profileId);

            return self::FAILURE;
        }

        try {
            $this->performLogin($driver);
        } catch (Throwable $e) {
            $this->error("Login automation failed: {$e->getMessage()}");

            return self::FAILURE;
        } finally {
            $this->info('Closing browser...');
            $driver->quit();
            $client->stopProfile($profileId);
        }

        $this->info('Demo completed successfully.');

        return self::SUCCESS;
    }

    /**
     * Navigate to the login page, fill in credentials, submit, and take screenshots.
     */
    private function performLogin(RemoteWebDriver $driver): void
    {
        $loginUrl = 'https://www.scrapingcourse.com/login/csrf';

        // Navigate to the login page
        $this->info("Navigating to {$loginUrl}...");
        $driver->get($loginUrl);

        // Wait for the page to load (email field present)
        $driver->wait(15, 500)->until(
            WebDriverExpectedCondition::presenceOfElementLocated(
                WebDriverBy::cssSelector('input[name="email"], input[type="email"], #email')
            )
        );

        $this->takeScreenshot($driver, '01_login_page');
        $this->info('Login page loaded.');

        // Find and fill the email field
        $emailField = $this->findElement($driver, [
            'input[name="email"]',
            'input[type="email"]',
            '#email',
        ]);

        if (! $emailField) {
            throw new RuntimeException('Could not find email input field.');
        }

        $emailField->clear();
        $emailField->sendKeys('admin@example.com');

        // Find and fill the password field
        $passwordField = $this->findElement($driver, [
            'input[name="password"]',
            'input[type="password"]',
            '#password',
        ]);

        if (! $passwordField) {
            throw new RuntimeException('Could not find password input field.');
        }

        $passwordField->clear();
        $passwordField->sendKeys('password');

        $this->takeScreenshot($driver, '02_credentials_filled');
        $this->info('Credentials entered.');

        // Find and click the submit button
        $submitButton = $this->findElement($driver, [
            'button[type="submit"]',
            'input[type="submit"]',
            'button:not([type])',
        ]);

        if (! $submitButton) {
            throw new RuntimeException('Could not find submit button.');
        }

        $submitButton->click();
        $this->info('Form submitted. Waiting for response...');

        // Wait for page navigation
        sleep(3);

        $currentUrl = $driver->getCurrentUrl();
        $this->takeScreenshot($driver, '03_after_login');
        $this->info("Current URL after login: {$currentUrl}");

        // Check page title or content for success indication
        $pageTitle = $driver->getTitle();
        $this->info("Page title: {$pageTitle}");
    }

    /**
     * Try multiple CSS selectors and return the first matching element.
     */
    private function findElement(RemoteWebDriver $driver, array $selectors): ?\Facebook\WebDriver\WebDriverElement
    {
        foreach ($selectors as $selector) {
            try {
                return $driver->findElement(WebDriverBy::cssSelector($selector));
            } catch (Throwable) {
                continue;
            }
        }

        return null;
    }

    /**
     * Take a screenshot and save it to storage.
     */
    private function takeScreenshot(RemoteWebDriver $driver, string $name): void
    {
        $disk = config('multilogin.screenshots_disk');
        $basePath = config('multilogin.screenshots_path');
        $timestamp = now()->format('Y-m-d_H-i-s');
        $filename = "{$basePath}/{$timestamp}_{$name}.png";

        $tempFile = tempnam(sys_get_temp_dir(), 'ml_screenshot_');
        $driver->takeScreenshot($tempFile);

        Storage::disk($disk)->put($filename, file_get_contents($tempFile));
        unlink($tempFile);

        $fullPath = Storage::disk($disk)->path($filename);
        $this->info("Screenshot saved: {$fullPath}");
    }
}
