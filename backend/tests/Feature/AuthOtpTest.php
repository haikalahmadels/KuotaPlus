<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * FR-1 dan kasus error di docs/API-KuotaPlus.md (Auth).
 */
class AuthOtpTest extends TestCase
{
    use RefreshDatabase;

    private const RINA = '6288100000001';

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PackageSeeder::class, SubscriberSeeder::class]);
    }

    private function requestOtp(string $msisdn = '0881-0000-0001')
    {
        return $this->postJson('/api/auth/otp/request', ['msisdn' => $msisdn]);
    }

    private function verify(string $code)
    {
        return $this->postJson('/api/auth/otp/verify', ['msisdn' => '0881-0000-0001', 'code' => $code, 'device_name' => 'test']);
    }

    private function wrongCode(string $code): string
    {
        return $code === '000000' ? '111111' : '000000';
    }

    public function test_request_accepts_common_number_formats_and_returns_demo_otp(): void
    {
        foreach (['0881-0000-0001', '+62 881 0000 0001', '6288100000001'] as $i => $format) {
            $this->travel(61)->seconds();
            $this->requestOtp($format)
                ->assertOk()
                ->assertJsonPath('data.msisdn', self::RINA)
                ->assertJsonStructure(['data' => ['expires_at', 'resend_available_at', 'demo_otp']]);
        }
    }

    public function test_demo_otp_hidden_when_not_exposed(): void
    {
        config(['services.otp.expose_code' => false]);

        $this->requestOtp()->assertOk()->assertJsonMissingPath('data.demo_otp');
    }

    public function test_rejects_invalid_unknown_and_terminated_numbers(): void
    {
        $this->requestOtp('12345')->assertStatus(422)->assertJsonPath('code', 'VALIDATION_FAILED');
        $this->requestOtp('0881-9999-9999')->assertStatus(404)
            ->assertJsonPath('code', 'NOT_SUBSCRIBER')
            ->assertJsonPath('message', 'Nomor bukan pelanggan Nusantel.');
        $this->requestOtp('0881-0000-0006')->assertStatus(403)->assertJsonPath('code', 'SUBSCRIBER_TERMINATED');
    }

    public function test_resend_waits_60_seconds(): void
    {
        $this->requestOtp()->assertOk();

        $this->travel(30)->seconds();
        $this->requestOtp()->assertStatus(429)
            ->assertJsonPath('code', 'OTP_RESEND_TOO_SOON')
            ->assertJsonPath('meta.retry_after', 30);

        $this->travel(31)->seconds();
        $this->requestOtp()->assertOk();
    }

    public function test_verify_success_creates_user_once_and_returns_working_token(): void
    {
        $code = $this->requestOtp()->json('data.demo_otp');
        $token = $this->verify($code)
            ->assertOk()
            ->assertJsonPath('data.user.msisdn', self::RINA)
            ->json('data.token');

        // Kode sekali pakai.
        $this->verify($code)->assertStatus(422)->assertJsonPath('code', 'OTP_EXPIRED');

        // Login kedua memakai akun yang sama.
        $this->travel(61)->seconds();
        $this->verify($this->requestOtp()->json('data.demo_otp'))->assertOk();
        $this->assertSame(1, User::count());

        $this->withToken($token)->postJson('/api/auth/logout')->assertNoContent();
    }

    public function test_wrong_code_counts_down_then_locks_for_15_minutes(): void
    {
        $code = $this->requestOtp()->json('data.demo_otp');
        $wrong = $this->wrongCode($code);

        foreach ([4, 3, 2, 1] as $left) {
            $this->verify($wrong)->assertStatus(422)
                ->assertJsonPath('code', 'OTP_INVALID')
                ->assertJsonPath('meta.attempts_left', $left);
        }

        $this->verify($wrong)->assertStatus(423)->assertJsonPath('code', 'OTP_LOCKED');

        // Kode yang benar pun ditolak selama terkunci, begitu juga minta kode baru.
        $this->verify($code)->assertStatus(423);
        $this->travel(61)->seconds();
        $this->requestOtp()->assertStatus(423)->assertJsonStructure(['meta' => ['locked_until']]);

        $this->travel(15)->minutes();
        $this->verify($this->requestOtp()->assertOk()->json('data.demo_otp'))->assertOk();
    }

    public function test_resend_does_not_reset_wrong_attempts(): void
    {
        $code = $this->requestOtp()->json('data.demo_otp');
        $this->verify($this->wrongCode($code))->assertJsonPath('meta.attempts_left', 4);

        $this->travel(61)->seconds();
        $code = $this->requestOtp()->json('data.demo_otp');
        $this->verify($this->wrongCode($code))->assertJsonPath('meta.attempts_left', 3);
    }

    public function test_code_expires_after_5_minutes(): void
    {
        $code = $this->requestOtp()->json('data.demo_otp');

        $this->travel(5)->minutes();
        $this->travel(1)->seconds();
        $this->verify($code)->assertStatus(422)->assertJsonPath('code', 'OTP_EXPIRED');
    }

    public function test_logout_revokes_token(): void
    {
        $token = $this->verify($this->requestOtp()->json('data.demo_otp'))->json('data.token');

        $this->withToken($token)->postJson('/api/auth/logout')->assertNoContent();
        $this->app['auth']->forgetGuards();

        $this->withToken($token)->postJson('/api/auth/logout')
            ->assertStatus(401)
            ->assertJsonPath('code', 'UNAUTHENTICATED');
    }

    public function test_otp_request_is_rate_limited_per_ip(): void
    {
        foreach (range(1, 5) as $i) {
            $this->requestOtp("0881-9999-000{$i}")->assertStatus(404);
        }

        $this->requestOtp('0881-9999-0006')->assertStatus(429)->assertJsonPath('code', 'TOO_MANY_REQUESTS');
    }
}
