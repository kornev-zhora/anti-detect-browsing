<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class MultiloginClient
{
    private ?string $bearerToken = null;

    public function __construct(
        private string $launcherUrl,
        private string $seleniumHost,
        private string $signinUrl,
        private ?string $username = null,
        private ?string $password = null,
    ) {}

    /**
     * Authenticate with the Multilogin cloud API to obtain a bearer token.
     * The password is MD5-hashed before sending as required by the API.
     *
     * @throws ConnectionException
     */
    public function authenticate(): string
    {
        if (! $this->username || ! $this->password) {
            throw new RuntimeException('MULTILOGIN_USERNAME and MULTILOGIN_PASSWORD must be configured.');
        }

        $response = Http::acceptJson()
            ->contentType('application/json')
            ->post($this->signinUrl, [
                'email' => $this->username,
                'password' => md5($this->password),
            ]);

        if (! $response->successful()) {
            throw new RuntimeException('Multilogin authentication failed: '.$response->body());
        }

        $this->bearerToken = $response->json('data.token');

        if (! $this->bearerToken) {
            throw new RuntimeException('No token in authentication response: '.$response->body());
        }

        return $this->bearerToken;
    }

    /**
     * Start a quick (disposable) browser profile via the MLX cloud launcher.
     *
     * @return array{id: string, port: string, browser_type: string, core_version: int, is_quick: bool}
     *
     * @throws ConnectionException
     */
    public function startQuickProfile(bool $headless = false, string $browserType = 'mimic', string $osType = 'linux'): array
    {
        $body = [
            'browser_type' => $browserType,
            'os_type' => $osType,
            'automation' => 'selenium',
            'is_headless' => $headless,
            'parameters' => [
                'flags' => [
                    'audio_masking' => 'natural',
                    'fonts_masking' => 'mask',
                    'geolocation_masking' => 'mask',
                    'geolocation_popup' => 'block',
                    'graphics_masking' => 'mask',
                    'graphics_noise' => 'mask',
                    'localization_masking' => 'mask',
                    'media_devices_masking' => 'natural',
                    'navigator_masking' => 'mask',
                    'ports_masking' => 'mask',
                    'proxy_masking' => 'disabled',
                    'screen_masking' => 'mask',
                    'timezone_masking' => 'mask',
                    'webrtc_masking' => 'mask',
                ],
                'fingerprint' => new \stdClass,
            ],
        ];

        $request = Http::acceptJson()
            ->contentType('application/json')
            ->timeout(120);

        if ($this->bearerToken) {
            $request = $request->withToken($this->bearerToken);
        }

        $response = $request->post("{$this->launcherUrl}/api/v3/profile/quick", $body);

        if (! $response->successful()) {
            throw new RuntimeException('Failed to start quick profile: '.$response->body());
        }

        $data = $response->json('data');

        if (! $data || ! isset($data['port'])) {
            throw new RuntimeException('Unexpected response from quick profile: '.$response->body());
        }

        return $data;
    }

    /**
     * Stop a running browser profile.
     *
     * @throws ConnectionException
     */
    public function stopProfile(string $profileId): bool
    {
        $request = Http::acceptJson()->timeout(30);

        if ($this->bearerToken) {
            $request = $request->withToken($this->bearerToken);
        }

        $response = $request->get("{$this->launcherUrl}/api/v1/profile/stop", [
            'profileId' => $profileId,
        ]);

        return $response->successful();
    }

    /**
     * Build the Selenium WebDriver URL from the returned port.
     */
    public function getSeleniumUrl(string $port): string
    {
        return "http://{$this->seleniumHost}:{$port}";
    }
}
