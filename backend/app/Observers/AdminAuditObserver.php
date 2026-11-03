<?php

namespace App\Observers;

use App\Models\AdminAuditLog;
use App\Models\Setting;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Request;

/**
 * FR-15.11: setiap create, update, dan delete oleh admin dicatat beserta nilai sebelum dan sesudahnya.
 * Perubahan oleh sistem (seeder, job, request pelanggan) tidak dicatat karena tidak ada admin yang masuk.
 */
class AdminAuditObserver
{
    /** Kolom yang tidak perlu dicatat. */
    private const IGNORED = ['created_at', 'updated_at', 'updated_by_admin_id'];

    public function created(Model $model): void
    {
        $this->log('create', $model, null, $this->clean($model, $model->getAttributes()));
    }

    public function updated(Model $model): void
    {
        $after = $this->clean($model, $model->getChanges());
        if ($after === []) {
            return;
        }
        $before = array_intersect_key($this->clean($model, $model->getRawOriginal()), $after);
        $this->log('update', $model, $before, $after);
    }

    public function deleted(Model $model): void
    {
        $this->log('delete', $model, $this->clean($model, $model->getRawOriginal()), null);
    }

    private function log(string $action, Model $model, ?array $before, ?array $after): void
    {
        $admin = Auth::guard('admin')->user();
        // Pengaturan sistem (catalog.updated_at) ikut berubah otomatis saat paket diubah; yang dicatat cukup paketnya.
        if ($admin === null || ($model instanceof Setting && $model->is_system)) {
            return;
        }

        AdminAuditLog::create([
            'admin_id' => $admin->getKey(),
            'action' => $action,
            'entity_type' => $model->getTable(),
            'entity_id' => $model->getKey(),
            'before' => $before,
            'after' => $after,
            'ip' => Request::ip(),
        ]);
    }

    private function clean(Model $model, array $attributes): array
    {
        // Kolom JSON (mis. settings.value) disimpan sebagai nilai aslinya, bukan string berescape.
        return collect($attributes)
            ->except(self::IGNORED)
            ->map(fn ($v, $key) => is_string($v) && $model->hasCast($key, ['array', 'json']) ? json_decode($v, true) : $v)
            ->all();
    }
}
