<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\HomeController;
use App\Http\Controllers\Api\TransactionController;
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
});
