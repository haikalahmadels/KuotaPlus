<?php

namespace App\Http\Resources;

use App\Models\App;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

/**
 * Objek bersama `Package` (docs/API-KuotaPlus.md). Gunakan list() supaya app_examples dimuat sekali untuk semua paket.
 */
class PackageResource extends JsonResource
{
    public function __construct($resource, private array $appExamples = [], private bool $isRecommended = false)
    {
        parent::__construct($resource);
    }

    /**
     * @param  Collection<int, \App\Models\Package>  $packages
     * @return Collection<int, self>
     */
    public static function list(Collection $packages, ?int $recommendedPackageId = null): Collection
    {
        // Contoh aplikasi per kategori untuk paket aplikasi (maksimal 5, label unik).
        $examples = App::whereIn('category', $packages->pluck('app_category')->filter()->unique())
            ->orderBy('id')
            ->get(['category', 'label'])
            ->groupBy('category')
            ->map(fn ($apps) => $apps->pluck('label')->unique()->take(5)->values()->all());

        return $packages->map(fn ($package) => new self(
            $package,
            $examples[$package->app_category] ?? [],
            $package->id === $recommendedPackageId,
        ));
    }

    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'name' => $this->name,
            'type' => $this->type,
            'price' => $this->price,
            'main_quota' => $this->main_quota,
            'app_quota' => $this->app_quota,
            'app_category' => $this->app_category,
            'app_examples' => $this->appExamples,
            'validity_days' => $this->validity_days,
            'is_recommended' => $this->isRecommended,
        ];
    }
}
