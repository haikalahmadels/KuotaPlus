<?php

namespace Tests\Feature;

use App\Models\Package;
use App\Models\PaymentCallback;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\User;
use App\Services\ForecastService;
use App\Services\PaymentService;
use App\Services\PointService;
use App\Services\SettingService;
use Database\Seeders\AppSeeder;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SettingSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\TestCase;

/**
 * DoD "Ketahanan pembayaran": callback ganda, setelah kedaluwarsa, signature salah, dan double-submit
 * tidak menghasilkan provisioning ganda (FR-5.5–5.8, edge case Bayar).
 */
class PaymentCallbackTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.payment.webhook_secret' => 'test-secret']);
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class]);
    }

    private function pending(string $msisdn, array $body): Transaction
    {
        Sanctum::actingAs(User::firstOrCreate(['subscriber_id' => Subscriber::where('msisdn', $msisdn)->value('id')]));
        $id = $this->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson('/api/transactions', $body + ['payment_method' => 'va'])
            ->assertCreated()
            ->json('data.id');

        return Transaction::find($id);
    }

    private function pendingPackage(string $code = 'VID30'): Transaction
    {
        return $this->pending('6288100000001', ['type' => 'package', 'package_id' => Package::where('code', $code)->value('id')]);
    }

    private function sendCallback(Transaction $transaction, string $status = 'PAID', ?string $signature = null)
    {
        $body = json_encode(['external_ref' => $transaction->external_ref, 'status' => $status]);

        return $this->call('POST', '/api/payments/callback', [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_SIGNATURE' => $signature ?? PaymentService::sign($body),
        ], $body);
    }

    public function test_paid_callback_provisions_package_once_even_if_repeated(): void
    {
        $transaction = $this->pendingPackage();

        $this->sendCallback($transaction)->assertOk();
        $this->sendCallback($transaction)->assertOk();
        $this->sendCallback($transaction, 'FAILED')->assertOk();

        $transaction->refresh();
        $this->assertSame('paid', $transaction->status);
        $this->assertNotNull($transaction->paid_at);
        $this->assertSame(1, Subscription::where('transaction_id', $transaction->id)->count());
        $this->assertSame(3, PaymentCallback::where('external_ref', $transaction->external_ref)->count());

        $this->getJson("/api/transactions/{$transaction->id}")
            ->assertJsonPath('data.status', 'paid')
            ->assertJsonPath('data.subscription_id', Subscription::where('transaction_id', $transaction->id)->value('id'));
    }

    public function test_failed_callback_marks_failed_without_provisioning(): void
    {
        $transaction = $this->pendingPackage();

        $this->sendCallback($transaction, 'FAILED')->assertOk();
        $this->sendCallback($transaction, 'PAID')->assertOk();

        $this->assertSame('failed', $transaction->fresh()->status);
        $this->assertSame(0, Subscription::whereNotNull('transaction_id')->count());
    }

    public function test_callback_after_expiry_is_rejected(): void
    {
        $transaction = $this->pendingPackage();

        $this->travel(16)->minutes();
        $this->sendCallback($transaction)->assertStatus(409)->assertJsonPath('code', 'TRANSACTION_EXPIRED');

        $this->assertSame('expired', $transaction->fresh()->status);
        $this->assertSame(0, Subscription::whereNotNull('transaction_id')->count());
    }

    public function test_wrong_signature_is_rejected_and_logged(): void
    {
        $transaction = $this->pendingPackage();

        $this->sendCallback($transaction, signature: str_repeat('0', 64))
            ->assertStatus(401)
            ->assertJsonPath('code', 'INVALID_SIGNATURE');

        $this->assertSame('pending', $transaction->fresh()->status);
        $this->assertFalse(PaymentCallback::sole()->signature_valid);
    }

    public function test_unknown_reference_returns_404(): void
    {
        $transaction = new Transaction(['external_ref' => 'KP-TIDAK-ADA']);

        $this->sendCallback($transaction)->assertStatus(404);
    }

    public function test_provisioning_failure_rolls_back_paid_status(): void
    {
        $transaction = $this->pendingPackage();

        $this->app->instance(PaymentService::class, new class(app(SettingService::class), app(ForecastService::class), app(PointService::class)) extends PaymentService
        {
            public function provision(Transaction $transaction): void
            {
                throw new RuntimeException('DB error');
            }
        });

        $this->sendCallback($transaction)->assertStatus(500)->assertJsonPath('code', 'SERVER_ERROR');

        $this->assertSame('pending', $transaction->fresh()->status, 'Tidak boleh ada PAID tanpa paket');
        $this->assertSame(0, Subscription::whereNotNull('transaction_id')->count());
        $this->assertTrue(PaymentCallback::sole()->signature_valid, 'Callback tetap tercatat untuk audit');
    }

    public function test_paid_topup_adds_pulsa_and_extends_from_current_active_until(): void
    {
        $rina = Subscriber::where('msisdn', '6288100000001')->first();
        $before = $rina->active_until->copy();
        $transaction = $this->pending('6288100000001', ['type' => 'topup', 'topup_amount' => 25000]);

        $this->sendCallback($transaction)->assertOk();

        $rina->refresh();
        $this->assertSame(12500 + 25000, $rina->pulsa_balance);
        $this->assertSame($before->addDays(30)->toDateString(), $rina->active_until->toDateString());
    }

    public function test_topup_during_grace_reactivates_number(): void
    {
        $transaction = $this->pending('6288100000005', ['type' => 'topup', 'topup_amount' => 10000]);

        $this->sendCallback($transaction)->assertOk();

        $sari = Subscriber::where('msisdn', '6288100000005')->first();
        $this->assertSame('active', $sari->status);
        $this->assertNull($sari->grace_until);
        $this->assertSame(today()->addDays(12)->toDateString(), $sari->active_until->toDateString()); // D-3 + 15
    }

    public function test_simulator_sends_signed_callback(): void
    {
        $transaction = $this->pendingPackage();
        Http::fake(['*/api/payments/callback' => Http::response(null, 200)]);

        $this->post("/simulator/{$transaction->external_ref}/pay")
            ->assertRedirect("/simulator/{$transaction->external_ref}");

        Http::assertSent(function ($request) use ($transaction) {
            $body = json_decode($request->body(), true);

            return $body['external_ref'] === $transaction->external_ref
                && $body['status'] === 'PAID'
                && hash_equals(PaymentService::sign($request->body()), $request->header('X-Signature')[0]);
        });

        $this->get("/simulator/{$transaction->external_ref}")->assertOk()->assertSee('Video 30 Hari')->assertSee('Rp65.000');
    }
}
