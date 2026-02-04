<?php

namespace App\Console\Commands;

use App\Services\GologinClient;
use Facebook\WebDriver\Chrome\ChromeOptions;
use Facebook\WebDriver\Remote\DesiredCapabilities;
use Facebook\WebDriver\Remote\RemoteWebDriver;
use Facebook\WebDriver\WebDriverBy;
use Facebook\WebDriver\WebDriverExpectedCondition;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Throwable;

class GologinLoginDemo extends Command
{
    protected $signature = 'app:gologin-login-demo
        {--profile= : Existing GoLogin profile ID (creates a new quick profile if omitted)}
        {--os=win : OS type for quick profile (win, mac, linux)}
        {--keep-profile : Do not delete the profile after the demo}';

    protected $description = 'Start a GoLogin cloud browser profile, login to scrapingcourse.com CSRF demo, and take screenshots';

    public function handle(): int
    {
        $client = new GologinClient(
            apiUrl: config('gologin.api_url'),
            cloudBrowserUrl: config('gologin.cloud_browser_url'),
            token: config('gologin.token'),
        );

        $profileId = $this->option('profile');
        $createdProfile = false;

        // Step 1: Create or use existing profile
        if (! $profileId) {
            $this->info('Creating quick browser profile...');

            try {
                $profileData = $client->createQuickProfile(
                    os: $this->option('os'),
                );
                $profileId = $profileData['id'];
                $createdProfile = true;
                $this->info("Profile created: {$profileId}");
            } catch (Throwable $e) {
                $this->error("Failed to create profile: {$e->getMessage()}");

                return self::FAILURE;
            }
        } else {
            $this->info("Using existing profile: {$profileId}");
        }

        // Step 2: Start the cloud browser
        $this->info('Starting cloud browser...');

        try {
            $wsUrl = $client->startCloudProfile($profileId);
            $this->info('Cloud browser started.');
            $this->info("WebSocket URL: {$wsUrl}");
        } catch (Throwable $e) {
            $this->error("Failed to start cloud browser: {$e->getMessage()}");
            $this->cleanupProfile($client, $profileId, $createdProfile);

            return self::FAILURE;
        }

        // Step 3: Connect via Selenium WebDriver using the debugger URL
        $this->info('Connecting to cloud browser via WebDriver...');
        $this->info('Waiting for browser to initialize...');
        sleep(5);

        try {
            $capabilities = DesiredCapabilities::chrome();
            $chromeOptions = new ChromeOptions;
            $chromeOptions->setExperimentalOption('debuggerAddress', $this->extractDebuggerAddress($wsUrl));
            $capabilities->setCapability(ChromeOptions::CAPABILITY, $chromeOptions);

            $driver = RemoteWebDriver::create(
                $wsUrl,
                $capabilities,
                60_000,
                60_000,
            );
        } catch (Throwable $e) {
            $this->error("Failed to connect to WebDriver: {$e->getMessage()}");
            $client->stopCloudProfile($profileId);
            $this->cleanupProfile($client, $profileId, $createdProfile);

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
            $client->stopCloudProfile($profileId);
            $this->cleanupProfile($client, $profileId, $createdProfile);
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

        $this->info("Navigating to {$loginUrl}...");
        $driver->get($loginUrl);

        $driver->wait(15, 500)->until(
            WebDriverExpectedCondition::presenceOfElementLocated(
                WebDriverBy::cssSelector('input[name="email"], input[type="email"], #email')
            )
        );

        $this->takeScreenshot($driver, '01_login_page');
        $this->info('Login page loaded.');

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

        sleep(3);

        $currentUrl = $driver->getCurrentUrl();
        $this->takeScreenshot($driver, '03_after_login');
        $this->info("Current URL after login: {$currentUrl}");

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
        $disk = config('gologin.screenshots_disk');
        $basePath = config('gologin.screenshots_path');
        $timestamp = now()->format('Y-m-d_H-i-s');
        $filename = "{$basePath}/gologin_{$timestamp}_{$name}.png";

        $tempFile = tempnam(sys_get_temp_dir(), 'gl_screenshot_');
        $driver->takeScreenshot($tempFile);

        Storage::disk($disk)->put($filename, file_get_contents($tempFile));
        unlink($tempFile);

        $fullPath = Storage::disk($disk)->path($filename);
        $this->info("Screenshot saved: {$fullPath}");
    }

    /**
     * Delete the profile if it was created during this run and --keep-profile was not set.
     */
    private function cleanupProfile(GologinClient $client, string $profileId, bool $wasCreated): void
    {
        if ($wasCreated && ! $this->option('keep-profile')) {
            $this->info("Deleting temporary profile {$profileId}...");

            try {
                $client->deleteProfile($profileId);
            } catch (Throwable $e) {
                $this->warn("Could not delete profile: {$e->getMessage()}");
            }
        }
    }

    /**
     * Extract the debugger host:port from a WebSocket URL.
     */
    private function extractDebuggerAddress(string $wsUrl): string
    {
        $parsed = parse_url($wsUrl);

        $host = $parsed['host'] ?? 'localhost';
        $port = $parsed['port'] ?? ($parsed['scheme'] === 'wss' ? 443 : 80);

        return "{$host}:{$port}";
    }
}
