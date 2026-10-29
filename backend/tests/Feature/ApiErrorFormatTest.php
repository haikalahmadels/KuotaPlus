<?php

namespace Tests\Feature;

use App\Exceptions\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use RuntimeException;
use Tests\TestCase;

class ApiErrorFormatTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Route::middleware('api')->prefix('api/_test')->group(function () {
            Route::post('/validate', fn (Request $request) => $request->validate(['msisdn' => 'required']));
            Route::get('/business', fn () => throw new ApiException(422, 'INSUFFICIENT_BALANCE', 'Pulsa tidak cukup.', ['shortfall' => 7000]));
            Route::get('/crash', fn () => throw new RuntimeException('detail rahasia'));
            Route::get('/auth', fn () => 'ok')->middleware('auth:sanctum');
        });
    }

    public function test_unknown_route_returns_not_found_code(): void
    {
        $this->getJson('/api/tidak-ada')
            ->assertStatus(404)
            ->assertExactJson(['message' => 'Data tidak ditemukan.', 'code' => 'NOT_FOUND']);
    }

    public function test_validation_error_keeps_field_errors(): void
    {
        $this->postJson('/api/_test/validate')
            ->assertStatus(422)
            ->assertJsonPath('code', 'VALIDATION_FAILED')
            ->assertJsonStructure(['message', 'code', 'errors' => ['msisdn']]);
    }

    public function test_business_error_carries_meta(): void
    {
        $this->getJson('/api/_test/business')
            ->assertStatus(422)
            ->assertExactJson(['message' => 'Pulsa tidak cukup.', 'code' => 'INSUFFICIENT_BALANCE', 'meta' => ['shortfall' => 7000]]);
    }

    public function test_unauthenticated_returns_401_code(): void
    {
        $this->getJson('/api/_test/auth')
            ->assertStatus(401)
            ->assertJsonPath('code', 'UNAUTHENTICATED');
    }

    public function test_server_error_hides_details(): void
    {
        config(['app.debug' => false]);

        $this->getJson('/api/_test/crash')
            ->assertStatus(500)
            ->assertExactJson(['message' => 'Terjadi kesalahan di server. Coba lagi.', 'code' => 'SERVER_ERROR']);
    }
}
