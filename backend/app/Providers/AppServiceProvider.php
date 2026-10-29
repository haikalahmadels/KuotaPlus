<?php

namespace App\Providers;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Mass assignment dibuka: input dari luar wajib lewat FormRequest, dan hanya validated() yang disimpan.
        Model::unguard();
        Model::shouldBeStrict(! $this->app->isProduction());
    }
}
