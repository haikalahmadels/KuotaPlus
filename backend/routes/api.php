<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\HomeController;
use App\Http\Controllers\Api\PointsController;
use App\Http\Controllers\Api\QuotaTransferController;
use App\Http\Controllers\Api\RecommendationController;
use App\Http\Controllers\Api\TransactionController;
use App\Http\Controllers\Api\UsageController;
use Illuminate\Support\Facades\Route;

// Endpoint ditambahkan per milestone sesuai docs/PLAN-KuotaPlus.md.

Route::prefix('auth')->group(function () {
    Route::post('otp/request', [AuthController::class, 'requestOtp'])->middleware('throttle:otp');
    Route::post('otp/verify', [AuthController::class, 'verifyOtp']);
    Route::post('logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
});

// Dipanggil simulator (server-ke-server), diamankan signature HMAC, bukan token.
Route::post('payments/callback', [TransactionController::class, 'callback']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('home', [HomeController::class, 'show']);
    Route::put('device', [HomeController::class, 'device']);
    Route::get('packages', [CatalogController::class, 'packages']);
    Route::get('topup-options', [CatalogController::class, 'topupOptions']);

    Route::post('transactions', [TransactionController::class, 'store']);
    Route::get('transactions', [TransactionController::class, 'index']);
    Route::get('transactions/{id}', [TransactionController::class, 'show'])->whereNumber('id');

    Route::post('usage/sync', [UsageController::class, 'sync']);
    Route::post('usage/demo', [UsageController::class, 'demo']);
    Route::get('usage/summary', [UsageController::class, 'summary']);
    Route::get('usage/apps/{id}', [UsageController::class, 'app'])->whereNumber('id');

    Route::get('recommendations', [RecommendationController::class, 'index']);
    Route::post('recommendations/{id}/click', [RecommendationController::class, 'click'])->whereNumber('id');

    Route::get('points', [PointsController::class, 'show']);
    Route::get('points/ledger', [PointsController::class, 'ledger']);

    Route::get('quota-transfers/quote', [QuotaTransferController::class, 'quote']);
    Route::post('quota-transfers/otp', [QuotaTransferController::class, 'otp'])->middleware('throttle:otp');
    Route::post('quota-transfers', [QuotaTransferController::class, 'store']);
    Route::get('quota-transfers', [QuotaTransferController::class, 'index']);
});
