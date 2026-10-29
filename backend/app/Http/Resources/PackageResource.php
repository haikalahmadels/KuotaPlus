<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Objek bersama `Package` (docs/API-KuotaPlus.md).
 * app_examples dan is_recommended dihitung controller lalu dioper lewat constructor.
 */
class PackageResource extends JsonResource
{
    public function __construct($resource, private array $appExamples = [], private bool $isRecommended = false)
    {
        parent::__construct($resource);
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
