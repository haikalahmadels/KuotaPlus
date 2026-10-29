<?php

namespace App\Http\Controllers\Api;

use App\Domain\UsageProfiles;
use App\Http\Controllers\Controller;
use App\Services\DemoDataService;
use App\Services\UsageSummaryService;
use App\Services\UsageSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class UsageController extends Controller
{
    /** POST /usage/sync (FR-7). forecast diisi di M5, alerts di M7. */
    public function sync(Request $request, UsageSyncService $sync): JsonResponse
    {
        $validated = $request->validate([
            'buckets' => ['present', 'array', 'max:2100'],
            'buckets.*.usage_date' => ['required', 'date_format:Y-m-d'],
            'buckets.*.package_name' => ['required', 'string', 'max:255'],
            'buckets.*.label' => ['required', 'string', 'max:255'],
            'buckets.*.bytes_mobile' => ['required', 'integer', 'min:0'],
        ]);

        return response()->json(['data' => $sync->sync($request->user(), $validated['buckets']) + [
            'forecast' => null,
            'alerts' => [],
        ]]);
    }

    /** POST /usage/demo (FR-7.8). */
    public function demo(Request $request, DemoDataService $demo): JsonResponse
    {
        $validated = $request->validate(['profile' => ['required', Rule::in(UsageProfiles::PROFILES)]]);

        return response()->json(['data' => [
            'days' => DemoDataService::DAYS,
            'total_bytes' => $demo->generate($request->user(), $validated['profile']),
            'forecast' => null,
        ]], 201);
    }

    /** GET /usage/summary (FR-8). */
    public function summary(Request $request, UsageSummaryService $usage): JsonResponse
    {
        return response()->json(['data' => $usage->summary($request->user(), $this->period($request))]);
    }

    /** GET /usage/apps/{id} (FR-8.4). */
    public function app(Request $request, int $id, UsageSummaryService $usage): JsonResponse
    {
        return response()->json(['data' => $usage->app($request->user(), $id, $this->period($request))]);
    }

    private function period(Request $request): string
    {
        return $request->validate(['period' => ['nullable', Rule::in(array_keys(UsageSummaryService::PERIOD_DAYS))]])['period'] ?? '7d';
    }
}
