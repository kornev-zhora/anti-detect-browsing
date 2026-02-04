<?php

use App\Services\GologinClient;
use Illuminate\Support\Facades\Http;

test('gologin client throws when token is missing', function () {
    $client = new GologinClient(
        apiUrl: 'https://api.gologin.com',
        cloudBrowserUrl: 'https://cloudbrowser.gologin.com',
    );

    $client->createQuickProfile();
})->throws(RuntimeException::class, 'GOLOGIN_TOKEN must be configured.');

test('gologin client creates quick profile', function () {
    Http::fake([
        'api.gologin.com/browser/quick' => Http::response([
            'id' => 'gl-profile-123',
            'name' => 'Quick Profile',
        ]),
    ]);

    $client = new GologinClient(
        apiUrl: 'https://api.gologin.com',
        cloudBrowserUrl: 'https://cloudbrowser.gologin.com',
        token: 'test-dev-token',
    );

    $data = $client->createQuickProfile('win');

    expect($data)->toHaveKey('id', 'gl-profile-123');

    Http::assertSent(function ($request) {
        return str_contains($request->url(), '/browser/quick')
            && $request['os'] === 'win'
            && $request->hasHeader('Authorization', 'Bearer test-dev-token');
    });
});

test('gologin client starts cloud profile and returns websocket url', function () {
    Http::fake([
        'api.gologin.com/browser/gl-profile-123/web' => Http::response([
            'wsUrl' => 'wss://cloudbrowser.gologin.com/connect?token=test-dev-token&profile=gl-profile-123',
        ]),
    ]);

    $client = new GologinClient(
        apiUrl: 'https://api.gologin.com',
        cloudBrowserUrl: 'https://cloudbrowser.gologin.com',
        token: 'test-dev-token',
    );

    $wsUrl = $client->startCloudProfile('gl-profile-123');

    expect($wsUrl)->toContain('cloudbrowser.gologin.com')
        ->toContain('gl-profile-123');

    Http::assertSent(function ($request) {
        return str_contains($request->url(), '/browser/gl-profile-123/web')
            && $request->method() === 'POST';
    });
});

test('gologin client falls back to built websocket url when wsUrl is missing', function () {
    Http::fake([
        'api.gologin.com/browser/gl-profile-456/web' => Http::response([
            'status' => 'started',
        ]),
    ]);

    $client = new GologinClient(
        apiUrl: 'https://api.gologin.com',
        cloudBrowserUrl: 'https://cloudbrowser.gologin.com',
        token: 'my-token',
    );

    $wsUrl = $client->startCloudProfile('gl-profile-456');

    expect($wsUrl)->toBe('https://cloudbrowser.gologin.com/connect?token=my-token&profile=gl-profile-456');
});

test('gologin client stops cloud profile', function () {
    Http::fake([
        'api.gologin.com/browser/gl-profile-123/web' => Http::response(null, 204),
    ]);

    $client = new GologinClient(
        apiUrl: 'https://api.gologin.com',
        cloudBrowserUrl: 'https://cloudbrowser.gologin.com',
        token: 'test-dev-token',
    );

    $result = $client->stopCloudProfile('gl-profile-123');

    expect($result)->toBeTrue();

    Http::assertSent(function ($request) {
        return str_contains($request->url(), '/browser/gl-profile-123/web')
            && $request->method() === 'DELETE';
    });
});

test('gologin client builds correct websocket url', function () {
    $client = new GologinClient(
        apiUrl: 'https://api.gologin.com',
        cloudBrowserUrl: 'https://cloudbrowser.gologin.com',
        token: 'my-dev-token',
    );

    expect($client->buildWebSocketUrl('profile-abc'))
        ->toBe('https://cloudbrowser.gologin.com/connect?token=my-dev-token&profile=profile-abc');

    expect($client->buildWebSocketUrl())
        ->toBe('https://cloudbrowser.gologin.com/connect?token=my-dev-token');
});

test('gologin client deletes profile', function () {
    Http::fake([
        'api.gologin.com/browser' => Http::response(null, 204),
    ]);

    $client = new GologinClient(
        apiUrl: 'https://api.gologin.com',
        cloudBrowserUrl: 'https://cloudbrowser.gologin.com',
        token: 'test-dev-token',
    );

    $result = $client->deleteProfile('gl-profile-123');

    expect($result)->toBeTrue();
});

test('gologin login demo command fails gracefully without api', function () {
    config([
        'gologin.api_url' => 'https://api.gologin.com',
        'gologin.cloud_browser_url' => 'https://cloudbrowser.gologin.com',
        'gologin.token' => 'test-token',
    ]);

    Http::fake([
        '*' => Http::response(['error' => 'Connection refused'], 500),
    ]);

    $this->artisan('app:gologin-login-demo')
        ->assertFailed();
});
