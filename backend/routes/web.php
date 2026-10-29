<?php

use App\Http\Controllers\SimulatorController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Simulator bank / e-wallet (FR-5.4), dibuka dari aplikasi lewat in-app browser.
Route::controller(SimulatorController::class)->prefix('simulator/{externalRef}')->name('simulator.')->group(function () {
    Route::get('/', 'show')->name('show');
    Route::post('pay', 'pay')->name('pay');
    Route::post('reject', 'reject')->name('reject');
});
