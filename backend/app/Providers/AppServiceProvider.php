<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
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

        // FR-15.11: perubahan oleh admin di panel tercatat di admin_audit_logs.
        foreach ([\App\Models\Package::class, \App\Models\App::class, \App\Models\Setting::class] as $model) {
            $model::observe(\App\Observers\AdminAuditObserver::class);
        }

        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(60)->by($request->user()?->id ?: $request->ip()));
        RateLimiter::for('otp', fn (Request $request) => Limit::perMinute(5)->by($request->ip()));
    }
}
