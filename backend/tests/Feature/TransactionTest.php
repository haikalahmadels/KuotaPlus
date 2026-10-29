<?php

namespace Tests\Feature;

use App\Models\Package;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\User;
use Database\Seeders\AppSeeder;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SettingSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * POST/GET /transactions (FR-3, FR-4, FR-5.2–5.3, FR-5.9, FR-6).
 */
class TransactionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class]);
    }

    private function actingAsNumber(string $msisdn): User
    {
        $user = User::create(['subscriber_id' => Subscriber::where('msisdn', $msisdn)->value('id')]);
        Sanctum::actingAs($user);

        return $user;
    }

    private function buy(string $code, string $method, ?string $key = null)
    {
        return $this->withHeader('Idempotency-Key', $key ?? (string) Str::uuid())->postJson('/api/transactions', [
            'type' => 'package',
            'package_id' => Package::where('code', $code)->value('id'),
            'payment_method' => $method,
        ]);
    }

    public function test_pulsa_payment_deducts_balance_and_activates_package_immediately(): void
    {
        $this->actingAsNumber('6288100000002'); // Budi, pulsa Rp150.000
        $budi = Subscriber::where('msisdn', '6288100000002')->first();
        $activeUntil = $budi->active_until->toDateString();

        $this->buy('BL15', 'pulsa')
            ->assertCreated()
            ->assertJsonPath('data.status', 'paid')
            ->assertJsonPath('data.item_name', 'Bulanan 15 GB')
            ->assertJsonPath('data.net_amount', 55000)
            ->assertJsonPath('data.payment', null);

        $budi->refresh();
        $this->assertSame(95000, $budi->pulsa_balance);
        $this->assertSame($activeUntil, $budi->active_until->toDateString(), 'Beli paket tidak memperpanjang masa aktif');

        $subscription = Subscription::where('subscriber_id', $budi->id)->sole();
        $this->assertSame(15 * 1073741824, $subscription->main_total);
        $this->assertEqualsWithDelta(30, now()->diffInDays($subscription->expires_at), 0.01);
    }

    public function test_insufficient_pulsa_is_rejected_with_shortfall(): void
    {
        $this->actingAsNumber('6288100000001'); // Rina, pulsa Rp12.500

        $this->buy('VID30', 'pulsa')
            ->assertStatus(422)
            ->assertJsonPath('code', 'INSUFFICIENT_BALANCE')
            ->assertJsonPath('meta.shortfall', 52500)
            ->assertJsonPath('message', 'Pulsa tidak cukup. Kurang Rp52.500.');

        $this->assertSame(0, Transaction::count());
    }

    public function test_non_pulsa_creates_pending_transaction_with_instructions(): void
    {
        $this->actingAsNumber('6288100000001');

        $va = $this->buy('VID30', 'va')->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.payment.bank_label', 'Bank A')
            ->json('data');
        $this->assertMatchesRegularExpression('/^8808\d{12}$/', $va['payment']['va_number']);
        $this->assertStringEndsWith('/simulator/'.$va['external_ref'], $va['payment']['simulator_url']);
        $this->assertEqualsWithDelta(15 * 60, now()->diffInSeconds($va['expires_at']), 2);

        $qris = $this->buy('VID30', 'qris')->json('data');
        $this->assertSame("NUSANTEL-QRIS|{$qris['external_ref']}|65000", $qris['payment']['qr_string']);

        $this->assertSame(0, Subscription::whereNotNull('transaction_id')->count(), 'Paket belum aktif sebelum dibayar');
    }

    public function test_same_idempotency_key_returns_same_transaction_without_double_charge(): void
    {
        $this->actingAsNumber('6288100000002');
        $key = (string) Str::uuid();

        $first = $this->buy('BL15', 'pulsa', $key)->assertCreated()->json('data.id');
        $this->buy('BL15', 'pulsa', $key)->assertOk()->assertJsonPath('data.id', $first);

        $this->assertSame(1, Transaction::count());
        $this->assertSame(1, Subscription::whereNotNull('transaction_id')->count());
        $this->assertSame(95000, Subscriber::where('msisdn', '6288100000002')->value('pulsa_balance'));
    }

    public function test_same_idempotency_key_with_different_body_is_rejected(): void
    {
        $this->actingAsNumber('6288100000002');
        $key = (string) Str::uuid();

        $this->buy('BL15', 'pulsa', $key)->assertCreated();
        $this->buy('BL25', 'pulsa', $key)->assertStatus(422)->assertJsonPath('code', 'IDEMPOTENCY_KEY_MISMATCH');
    }

    public function test_idempotency_key_header_is_required(): void
    {
        $this->actingAsNumber('6288100000002');

        $this->postJson('/api/transactions', ['type' => 'package', 'package_id' => 1, 'payment_method' => 'va'])
            ->assertStatus(400)
            ->assertJsonPath('code', 'IDEMPOTENCY_KEY_REQUIRED');
    }

    public function test_grace_subscriber_cannot_buy_package_but_can_top_up(): void
    {
        $this->actingAsNumber('6288100000005'); // Sari, masa tenggang

        $this->buy('HR1', 'va')->assertStatus(403)->assertJsonPath('code', 'SUBSCRIBER_IN_GRACE');

        $this->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson('/api/transactions', ['type' => 'topup', 'topup_amount' => 10000, 'payment_method' => 'va'])
            ->assertCreated()
            ->assertJsonPath('data.item_name', 'Isi ulang Rp10.000');
    }

    public function test_inactive_package_and_invalid_topup_are_rejected(): void
    {
        $this->actingAsNumber('6288100000002');

        $this->buy('HR05', 'va')->assertStatus(422)->assertJsonPath('code', 'PACKAGE_INACTIVE');

        $topup = fn (array $body) => $this->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson('/api/transactions', ['type' => 'topup'] + $body);

        $topup(['topup_amount' => 7000, 'payment_method' => 'va'])
            ->assertStatus(422)->assertJsonValidationErrors(['topup_amount']);
        $topup(['topup_amount' => 10000, 'payment_method' => 'pulsa'])
            ->assertStatus(422)->assertJsonValidationErrors(['payment_method']);
    }

    public function test_history_lists_own_transactions_newest_first_without_payment_details(): void
    {
        $rina = $this->actingAsNumber('6288100000001');
        $this->buy('HR1', 'va');
        $this->buy('VID30', 'qris');

        $other = User::create(['subscriber_id' => Subscriber::where('msisdn', '6288100000002')->value('id')]);
        Sanctum::actingAs($other);
        $othersId = $this->buy('HR1', 'pulsa')->json('data.id');

        Sanctum::actingAs($rina);
        $this->getJson('/api/transactions')
            ->assertOk()
            ->assertJsonPath('data.*.item_name', ['Video 30 Hari', 'Harian 1 GB'])
            ->assertJsonMissingPath('data.0.payment')
            ->assertJsonPath('meta.total', 2);

        $this->getJson('/api/transactions?status=paid')->assertJsonPath('meta.total', 0);
        $this->getJson("/api/transactions/{$othersId}")->assertStatus(404)->assertJsonPath('code', 'NOT_FOUND');
    }
}
