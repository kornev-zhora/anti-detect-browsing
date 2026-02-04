<?php

use App\Services\MultiloginClient;
use Illuminate\Support\Facades\Http;

test('multilogin client authenticates and receives bearer token', function () {
    Http::fake([
        'api.multilogin.com/user/signin' => Http::response([
            'data' => ['token' => 'test-bearer-token-123'],
        ]),
    ]);

    $client = new MultiloginClient(
        launcherUrl: 'http://localhost:35000',
        seleniumHost: '127.0.0.1',
        signinUrl: 'https://api.multilogin.com/user/signin',
        username: 'test@example.com',
        password: 'secret',
    );

    $token = $client->authenticate();

    expect($token)->toBe('test-bearer-token-123');

    Http::assertSent(function ($request) {
        return $request->url() === 'https://api.multilogin.com/user/signin'
            && $request['email'] === 'test@example.com'
            && $request['password'] === 'secret';
    });
});

test('multilogin client throws when credentials are missing', function () {
    $client = new MultiloginClient(
        launcherUrl: 'http://localhost:35000',
        seleniumHost: '127.0.0.1',
        signinUrl: 'https://api.multilogin.com/user/signin',
    );

    $client->authenticate();
})->throws(RuntimeException::class, 'MULTILOGIN_USERNAME and MULTILOGIN_PASSWORD must be configured.');

test('multilogin client starts quick profile and returns data', function () {
    Http::fake([
        'localhost:35000/api/v3/profile/quick' => Http::response([
            'data' => [
                'browser_type' => 'mimic',
                'core_version' => 132,
                'id' => 'test-profile-id',
                'is_quick' => true,
                'port' => '55579',
            ],
            'status' => [
                'error_code' => '',
                'http_code' => 200,
                'message' => 'Quick profile started successfully',
            ],
        ]),
    ]);

    $client = new MultiloginClient(
        launcherUrl: 'http://localhost:35000',
        seleniumHost: '127.0.0.1',
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

test('multilogin client builds correct selenium url', function () {
    $client = new MultiloginClient(
        launcherUrl: 'http://localhost:35000',
        seleniumHost: 'multilogin-unofficial',
        signinUrl: 'https://api.multilogin.com/user/signin',
    );

    expect($client->getSeleniumUrl('55579'))->toBe('http://multilogin-unofficial:55579');
});

test('multilogin client stops profile', function () {
    Http::fake([
        'localhost:35000/api/v1/profile/stop*' => Http::response(['status' => 'OK']),
    ]);

    $client = new MultiloginClient(
        launcherUrl: 'http://localhost:35000',
        seleniumHost: '127.0.0.1',
        signinUrl: 'https://api.multilogin.com/user/signin',
    );

    $result = $client->stopProfile('test-profile-id');

    expect($result)->toBeTrue();

    Http::assertSent(function ($request) {
        return str_contains($request->url(), '/api/v1/profile/stop')
            && $request['profileId'] === 'test-profile-id';
    });
});

test('multilogin login demo command fails gracefully without api', function () {
    Http::fake([
        '*' => Http::response(['error' => 'Connection refused'], 500),
    ]);

    $this->artisan('app:multilogin-login-demo')
        ->assertFailed();
});
