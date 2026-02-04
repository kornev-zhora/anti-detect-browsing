<?php

use App\Services\MultiloginClient;
use Illuminate\Support\Facades\Http;

test('multilogin client authenticates with md5 hashed password', function () {
    Http::fake([
        'api.multilogin.com/user/signin' => Http::response([
            'data' => ['token' => 'test-bearer-token-123'],
        ]),
    ]);

    $client = new MultiloginClient(
        launcherUrl: 'https://launcher.mlx.yt:45001',
        seleniumHost: 'host.docker.internal',
        signinUrl: 'https://api.multilogin.com/user/signin',
        username: 'test@example.com',
        password: 'secret',
    );

    $token = $client->authenticate();

    expect($token)->toBe('test-bearer-token-123');

    Http::assertSent(function ($request) {
        return $request->url() === 'https://api.multilogin.com/user/signin'
            && $request['email'] === 'test@example.com'
            && $request['password'] === md5('secret');
    });
});

test('multilogin client throws when credentials are missing', function () {
    $client = new MultiloginClient(
        launcherUrl: 'https://launcher.mlx.yt:45001',
        seleniumHost: 'host.docker.internal',
        signinUrl: 'https://api.multilogin.com/user/signin',
    );

    $client->authenticate();
})->throws(RuntimeException::class, 'MULTILOGIN_USERNAME and MULTILOGIN_PASSWORD must be configured.');

test('multilogin client starts quick profile via v3 launcher', function () {
    Http::fake([
        'launcher.mlx.yt:45001/api/v3/profile/quick' => Http::response([
            'data' => [
                'browser_type' => 'mimic',
                'core_version' => 132,
                'id' => 'test-profile-id',
                'is_quick' => true,
                'port' => '55579',
            ],
        ]),
    ]);

    $client = new MultiloginClient(
        launcherUrl: 'https://launcher.mlx.yt:45001',
        seleniumHost: 'host.docker.internal',
        signinUrl: 'https://api.multilogin.com/user/signin',
    );

    $data = $client->startQuickProfile();

    expect($data)
        ->toHaveKey('id', 'test-profile-id')
        ->toHaveKey('port', '55579')
        ->toHaveKey('browser_type', 'mimic')
        ->toHaveKey('is_quick', true);

    Http::assertSent(function ($request) {
        return str_contains($request->url(), '/api/v3/profile/quick')
            && $request['browser_type'] === 'mimic'
            && $request['automation'] === 'selenium';
    });
});

test('multilogin client sends bearer token with quick profile request', function () {
    Http::fake([
        'api.multilogin.com/user/signin' => Http::response([
            'data' => ['token' => 'my-jwt-token'],
        ]),
        'launcher.mlx.yt:45001/api/v3/profile/quick' => Http::response([
            'data' => [
                'browser_type' => 'mimic',
                'core_version' => 132,
                'id' => 'test-id',
                'is_quick' => true,
                'port' => '55580',
            ],
        ]),
    ]);

    $client = new MultiloginClient(
        launcherUrl: 'https://launcher.mlx.yt:45001',
        seleniumHost: 'host.docker.internal',
        signinUrl: 'https://api.multilogin.com/user/signin',
        username: 'test@example.com',
        password: 'secret',
    );

    $client->authenticate();
    $client->startQuickProfile();

    Http::assertSent(function ($request) {
        return str_contains($request->url(), '/api/v3/profile/quick')
            && $request->hasHeader('Authorization', 'Bearer my-jwt-token');
    });
});

test('multilogin client builds correct selenium url', function () {
    $client = new MultiloginClient(
        launcherUrl: 'https://launcher.mlx.yt:45001',
        seleniumHost: 'host.docker.internal',
        signinUrl: 'https://api.multilogin.com/user/signin',
    );

    expect($client->getSeleniumUrl('55579'))->toBe('http://host.docker.internal:55579');
});

test('multilogin client stops profile', function () {
    Http::fake([
        'launcher.mlx.yt:45001/api/v1/profile/stop*' => Http::response(['status' => 'OK']),
    ]);

    $client = new MultiloginClient(
        launcherUrl: 'https://launcher.mlx.yt:45001',
        seleniumHost: 'host.docker.internal',
        signinUrl: 'https://api.multilogin.com/user/signin',
    );

    $result = $client->stopProfile('test-profile-id');

    expect($result)->toBeTrue();
});

test('multilogin login demo command fails gracefully without api', function () {
    Http::fake([
        '*' => Http::response(['error' => 'Connection refused'], 500),
    ]);

    $this->artisan('app:multilogin-login-demo')
        ->assertFailed();
});
