<?php

return [

    /*
    |--------------------------------------------------------------------------
    | GoLogin Cloud Browser API Configuration
    |--------------------------------------------------------------------------
    |
    | The API base URL and token for interacting with GoLogin's cloud browser
    | service. Obtain your dev token from Settings > API in GoLogin dashboard.
    |
    */

    'api_url' => env('GOLOGIN_API_URL', 'https://api.gologin.com'),

    'cloud_browser_url' => env('GOLOGIN_CLOUD_BROWSER_URL', 'https://cloudbrowser.gologin.com'),

    'token' => env('GOLOGIN_TOKEN'),

    'screenshots_disk' => env('GOLOGIN_SCREENSHOTS_DISK', 'local'),

    'screenshots_path' => env('GOLOGIN_SCREENSHOTS_PATH', 'screenshots'),

];
