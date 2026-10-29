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

class ScheduledCommandsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class]);
    }

    public function test_pending_transactions_expire_after_15_minutes(): void
    {
        Sanctum::actingAs(User::create(['subscriber_id' => Subscriber::where('msisdn', '6288100000001')->value('id')]));
        $id = $this->withHeader('Idempotency-Key', (string) Str::uuid())->postJson('/api/transactions', [
            'type' => 'package', 'package_id' => Package::where('code', 'HR1')->value('id'), 'payment_method' => 'qris',
        ])->json('data.id');

        $this->artisan('transactions:expire')->assertSuccessful();
        $this->assertSame('pending', Transaction::find($id)->status);

        $this->travel(16)->minutes();
        $this->artisan('transactions:expire')->assertSuccessful();
        $this->assertSame('expired', Transaction::find($id)->status);
    }

    public function test_subscriptions_past_expiry_become_expired(): void
    {
        $ujiHp = Subscription::sole();

        $this->travel(31)->days();
        $this->artisan('subscriptions:expire')->assertSuccessful();

        $this->assertSame('expired', $ujiHp->fresh()->status);
    }

    public function test_card_moves_to_grace_then_terminated_and_tokens_are_revoked(): void
    {
        $uji = Subscriber::where('msisdn', '6288100000004')->first(); // aktif s.d. D+60
        $sari = Subscriber::where('msisdn', '6288100000005')->first(); // tenggang s.d. D+12
        $sariUser = User::create(['subscriber_id' => $sari->id]);
        $sariUser->createToken('test');

        $this->travel(13)->days();
        $this->artisan('subscribers:status')->assertSuccessful();

        $this->assertSame('terminated', $sari->fresh()->status);
        $this->assertSame(0, $sariUser->tokens()->count());
        $this->assertSame('active', $uji->fresh()->status);

        $this->travel(48)->days(); // D+61
        $this->artisan('subscribers:status')->assertSuccessful();

        $uji->refresh();
        $this->assertSame('grace', $uji->status);
        $this->assertSame($uji->active_until->copy()->addDays(15)->toDateString(), $uji->grace_until->toDateString());
    }
}
