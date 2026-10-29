<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PackageResource;
use App\Models\App;
use App\Models\Package;
use App\Services\SettingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CatalogController extends Controller
{
    private const GROUP_ORDER = ['harian', 'mingguan', 'bulanan', 'aplikasi'];

    public function __construct(private SettingService $settings) {}

    /** GET /packages (FR-3.1–3.2). is_recommended diisi di M5. */
    public function packages(Request $request): JsonResponse
    {
        $packages = Package::where('is_active', true)->orderBy('price')->get()->groupBy('type');

        // Contoh aplikasi per kategori untuk paket aplikasi (maksimal 5, label unik).
        $examples = App::whereIn('category', $packages->flatten()->pluck('app_category')->filter()->unique())
            ->orderBy('id')
            ->get(['category', 'label'])
            ->groupBy('category')
            ->map(fn ($apps) => $apps->pluck('label')->unique()->take(5)->values()->all());

        return response()->json(['data' => [
            'groups' => collect(self::GROUP_ORDER)->map(fn ($type) => [
                'type' => $type,
                'packages' => ($packages[$type] ?? collect())
                    ->map(fn ($package) => new PackageResource($package, $examples[$package->app_category] ?? []))
                    ->values(),
            ]),
            'points' => [
                'balance' => $request->user()->pointBalance(),
                'rupiah_per_point' => $this->settings->int('points.rupiah_per_point'),
                'redeem_step' => $this->settings->int('points.redeem_step'),
                'max_discount_percent' => $this->settings->int('points.max_discount_percent'),
                'min_net_amount' => $this->settings->int('points.min_net_amount'),
            ],
        ]]);
    }

    /** GET /topup-options (FR-4.1, OQ-2). */
    public function topupOptions(): JsonResponse
    {
        return response()->json(['data' => $this->settings->get('topup.options')]);
    }
}
