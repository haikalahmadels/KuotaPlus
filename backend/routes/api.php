<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

// Endpoint ditambahkan per milestone sesuai docs/PLAN-KuotaPlus.md.

Route::prefix('auth')->group(function () {
    Route::post('otp/request', [AuthController::class, 'requestOtp'])->middleware('throttle:otp');
    Route::post('otp/verify', [AuthController::class, 'verifyOtp']);
    Route::post('logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
});
