<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class GologinClient
{
    public function __construct(
        private string $apiUrl,
        private string $cloudBrowserUrl,
        private ?string $token = null,
    ) {}

    /**
     * Create a quick browser profile with a random fingerprint.
     *
     * @return array{id: string}
     *
     * @throws ConnectionException
     */
    public function createQuickProfile(string $os = 'win', ?string $name = null): array
    {
        $response = $this->authenticatedRequest()
            ->post("{$this->apiUrl}/browser/quick", [
                'name' => $name ?? 'Profile '.now()->format('Y-m-d H:i:s'),
                'os' => $os,
            ]);

        if (! $response->successful()) {
            throw new RuntimeException('Failed to create quick profile: '.$response->body());
        }

        $id = $response->json('id');

        if (! $id) {
            throw new RuntimeException('No profile ID in response: '.$response->body());
        }

        return ['id' => $id];
    }

    /**
     * Start a profile in the GoLogin cloud and return the WebSocket connection URL.
     *
     * @throws ConnectionException
     */
    public function startCloudProfile(string $profileId): string
    {
        $response = $this->authenticatedRequest()
            ->timeout(120)
            ->post("{$this->apiUrl}/browser/{$profileId}/web");

        if (! $response->successful()) {
            throw new RuntimeException('Failed to start cloud profile: '.$response->body());
        }

        return $response->json('wsUrl')
            ?? $this->buildWebSocketUrl($profileId);
    }

    /**
     * Stop a running cloud browser profile.
     *
     * @throws ConnectionException
     */
    public function stopCloudProfile(string $profileId): bool
    {
        $response = $this->authenticatedRequest()
            ->timeout(30)
            ->delete("{$this->apiUrl}/browser/{$profileId}/web");

        return $response->successful();
    }

    /**
     * Delete a browser profile.
     *
     * @throws ConnectionException
     */
    public function deleteProfile(string $profileId): bool
    {
        $response = $this->authenticatedRequest()
            ->timeout(30)
            ->delete("{$this->apiUrl}/browser", [
                'ids' => [$profileId],
            ]);

        return $response->successful();
    }

    /**
     * Get profile information by ID.
     *
     * @return array<string, mixed>
     *
     * @throws ConnectionException
     */
    public function getProfile(string $profileId): array
    {
        $response = $this->authenticatedRequest()
            ->get("{$this->apiUrl}/browser/{$profileId}");

        if (! $response->successful()) {
            throw new RuntimeException('Failed to get profile: '.$response->body());
        }

        return $response->json();
    }

    /**
     * Build the WebSocket URL for connecting to a cloud browser profile.
     */
    public function buildWebSocketUrl(?string $profileId = null): string
    {
        $url = "{$this->cloudBrowserUrl}/connect?token={$this->token}";

        if ($profileId) {
            $url .= "&profile={$profileId}";
        }

        return $url;
    }

    /**
     * Build an authenticated HTTP request with the GoLogin dev token.
     */
    private function authenticatedRequest(): \Illuminate\Http\Client\PendingRequest
    {
        if (! $this->token) {
            throw new RuntimeException('GOLOGIN_TOKEN must be configured.');
        }

        return Http::acceptJson()
            ->contentType('application/json')
            ->withToken($this->token);
    }
}
