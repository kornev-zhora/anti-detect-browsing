<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Multilogin X API Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for connecting to the Multilogin X launcher API.
    | The launcher URL points to the local Multilogin headless service.
    | The Selenium host is used to connect to browser WebDriver ports.
    |
    */

    'launcher_url' => env('MULTILOGIN_LAUNCHER_URL', 'http://localhost:35000'),

    'selenium_host' => env('MULTILOGIN_SELENIUM_HOST', '127.0.0.1'),

    'signin_url' => env('MULTILOGIN_SIGNIN_URL', 'https://api.multilogin.com/user/signin'),

    'username' => env('MULTILOGIN_USERNAME'),

    'password' => env('MULTILOGIN_PASSWORD'),

    'screenshots_disk' => env('MULTILOGIN_SCREENSHOTS_DISK', 'local'),

    'screenshots_path' => env('MULTILOGIN_SCREENSHOTS_PATH', 'screenshots'),

];
