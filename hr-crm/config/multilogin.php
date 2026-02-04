<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Multilogin X API Configuration
    |--------------------------------------------------------------------------
    |
    | The launcher URL is the MLX cloud launcher that manages quick profiles.
    | The Selenium host is where browser WebDriver ports are accessible
    | (the machine running the Multilogin agent / Docker container).
    |
    */

    'launcher_url' => env('MULTILOGIN_LAUNCHER_URL', 'https://launcher.mlx.yt:45001'),

    'selenium_host' => env('MULTILOGIN_SELENIUM_HOST', 'host.docker.internal'),

    'signin_url' => env('MULTILOGIN_SIGNIN_URL', 'https://api.multilogin.com/user/signin'),

    'username' => env('MULTILOGIN_USERNAME'),

    'password' => env('MULTILOGIN_PASSWORD'),

    'screenshots_disk' => env('MULTILOGIN_SCREENSHOTS_DISK', 'local'),

    'screenshots_path' => env('MULTILOGIN_SCREENSHOTS_PATH', 'screenshots'),

];
