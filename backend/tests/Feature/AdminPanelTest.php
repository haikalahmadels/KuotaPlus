<?php

namespace Tests\Feature;

use App\Exceptions\ApiException;
use App\Filament\Resources\Packages\Pages\EditPackage;
use App\Filament\Resources\Settings\Pages\EditSetting;
use App\Models\Admin;
use App\Models\AdminAuditLog;
use App\Models\Package;
use App\Models\QuotaTransfer;
use App\Models\Setting;
use App\Models\Subscriber;
use App\Models\Transaction;
use App\Models\User;
use Database\Seeders\AppSeeder;
use Database\Seeders\DemoAccountSeeder;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SettingSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\Sanctum;
use Livewire\Livewire;
use LogicException;
use Tests\TestCase;

/**
 * FR-15 dan DoD "Panel admin": akses terpisah dari pelanggan, validasi pengaturan, paket yang pernah dibeli,
 * audit log, dan perubahan admin terlihat di API Flutter.
 */
class AdminPanelTest extends TestCase
{
    use RefreshDatabase;

    private Admin $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class, DemoAccountSeeder::class]);
        $this->admin = Admin::create(['name' => 'Admin Uji', 'email' => 'admin@uji.test', 'password' => 'rahasia-panjang']);
    }

    private function asAdmin(): static
    {
        return $this->actingAs($this->admin, 'admin');
    }

    public function test_guest_and_customer_token_cannot_open_panel(): void
    {
        $this->get('/admin')->assertRedirect('/admin/login');

        Sanctum::actingAs(User::firstOrFail());
        $this->get('/admin')->assertRedirect('/admin/login');
        $this->get('/admin/packages')->assertRedirect('/admin/login');
    }

    public function test_every_panel_page_renders_for_admin(): void
    {
        $this->asAdmin();
        $pages = [
            '/admin',
            '/admin/packages', '/admin/packages/create', '/admin/packages/'.Package::first()->id.'/edit',
            '/admin/apps', '/admin/apps/'.\App\Models\App::first()->id.'/edit',
            '/admin/settings', '/admin/settings/'.Setting::where('key', 'reward.points_per_day')->value('id').'/edit',
            '/admin/settings/'.Setting::where('key', 'topup.options')->value('id').'/edit',
            '/admin/transactions', '/admin/transactions/'.Transaction::first()->id,
            '/admin/subscribers', '/admin/subscribers/'.Subscriber::where('msisdn', '6288100000002')->value('id'),
            '/admin/quota-transfers', '/admin/quota-transfers/'.QuotaTransfer::first()->id,
            '/admin/admin-audit-logs',
        ];

        foreach ($pages as $page) {
            $this->get($page)->assertOk();
        }
    }

    public function test_read_only_resources_have_no_create_or_edit_routes(): void
    {
        $this->asAdmin();

        $this->get('/admin/transactions/create')->assertNotFound();
        $this->get('/admin/subscribers/create')->assertNotFound();
        $this->get('/admin/admin-audit-logs/create')->assertNotFound();
    }

    public function test_setting_outside_its_range_is_rejected(): void
    {
        $this->asAdmin();
        $setting = Setting::where('key', 'reward.points_per_day')->first(); // rentang 1–100

        Livewire::test(EditSetting::class, ['record' => $setting->getRouteKey()])
            ->fillForm(['value' => 500])
            ->call('save')
            ->assertHasFormErrors(['value']);
        $this->assertSame(10, $setting->fresh()->value);

        // Model juga menolak, apa pun jalurnya.
        $this->expectException(ValidationException::class);
        $setting->update(['value' => 0]);
    }

    public function test_package_that_was_purchased_cannot_be_deleted_but_new_one_can(): void
    {
        $purchased = Transaction::where('type', 'package')->firstOrFail()->package;

        try {
            $purchased->delete();
            $this->fail('Paket yang pernah dibeli tidak boleh terhapus.');
        } catch (ApiException $e) {
            $this->assertSame('PACKAGE_PURCHASED', $e->errorCode);
        }
        $this->assertModelExists($purchased);

        $fresh = Package::create([
            'code' => 'UJI1', 'name' => 'Uji', 'type' => 'harian', 'price' => 1000,
            'main_quota' => 1048576, 'app_quota' => 0, 'validity_days' => 1, 'is_active' => true,
        ]);
        $fresh->delete();
        $this->assertModelMissing($fresh);
    }

    public function test_price_change_in_panel_reaches_the_app_and_is_audited(): void
    {
        $this->asAdmin();
        $package = Package::where('code', 'BL15')->firstOrFail();
        $catalogBefore = Setting::where('key', 'catalog.updated_at')->value('value');
        $this->travel(1)->minutes();

        Livewire::test(EditPackage::class, ['record' => $package->getRouteKey()])
            ->fillForm(['price' => 58000])
            ->call('save')
            ->assertHasNoFormErrors();

        // DoD: harga baru terlihat di aplikasi Flutter (GET /packages) tanpa mengubah kode.
        Sanctum::actingAs(User::firstOrFail());
        $prices = collect($this->getJson('/api/packages')->assertOk()->json('data.groups'))
            ->flatMap(fn ($g) => $g['packages'])->pluck('price', 'code');
        $this->assertSame(58000, $prices['BL15']);

        // Kuota tidak berubah walau form mengisinya dalam MB.
        $this->assertSame($package->main_quota, $package->fresh()->main_quota);
        $this->assertNotSame($catalogBefore, Setting::where('key', 'catalog.updated_at')->value('value'));

        $log = AdminAuditLog::where(['entity_type' => 'packages', 'entity_id' => $package->id])->sole();
        $this->assertSame('update', $log->action);
        $this->assertSame($this->admin->id, $log->admin_id);
        $this->assertSame(['price' => $package->price], $log->before);
        $this->assertSame(['price' => 58000], $log->after);
    }

    public function test_reward_setting_change_is_audited_and_used_by_the_app(): void
    {
        $this->asAdmin();
        $setting = Setting::where('key', 'reward.points_per_day')->first();

        Livewire::test(EditSetting::class, ['record' => $setting->getRouteKey()])
            ->fillForm(['value' => 25])
            ->call('save')
            ->assertHasNoFormErrors();

        $log = AdminAuditLog::where(['entity_type' => 'settings', 'entity_id' => $setting->id])->sole();
        $this->assertSame(['value' => 10], $log->before);
        $this->assertSame(['value' => 25], $log->after);
        $this->assertSame($this->admin->id, $setting->fresh()->updated_by_admin_id);

        Sanctum::actingAs(User::firstOrFail());
        $this->getJson('/api/points')->assertOk()->assertJsonPath('data.rules.points_per_day', 25);
    }

    public function test_audit_log_cannot_be_changed_or_deleted_and_system_changes_are_not_logged(): void
    {
        // Perubahan tanpa admin masuk (seeder, job) tidak dicatat.
        Package::where('code', 'BL15')->first()->update(['price' => 1]);
        $this->assertSame(0, AdminAuditLog::count());

        $this->asAdmin();
        Package::where('code', 'BL15')->first()->update(['price' => 2]);
        $log = AdminAuditLog::sole();

        try {
            $log->update(['action' => 'delete']);
            $this->fail('Audit log tidak boleh diubah.');
        } catch (LogicException) {
        }
        $this->expectException(LogicException::class);
        $log->delete();
    }
}
