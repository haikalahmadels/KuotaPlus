<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PackageResource;
use App\Services\RecommendationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class RecommendationController extends Controller
{
    /** GET /recommendations (FR-10). */
    public function index(Request $request, RecommendationService $recommendations): JsonResponse
    {
        $current = $recommendations->current($request->user());
        $packages = PackageResource::list($current['items']->pluck('package'))->keyBy(fn ($resource) => $resource->id);

        return response()->json(['data' => [
            'status' => $current['status'],
            'need' => $current['need'],
            'spent_30d' => $current['spent_30d'],
            'items' => $current['items']->map(fn ($item) => [
                'id' => $item->id,
                'rank' => $item->rank,
                'package' => $packages[$item->package_id],
                'cost_30d' => $item->cost_30d,
                'saving_30d' => $item->saving_30d,
                'leftover_bytes' => $item->leftover_bytes,
                'reason' => $item->reason,
            ])->values(),
        ]]);
    }

    /** POST /recommendations/{id}/click (FR-10.8). Klik pertama yang dicatat. */
    public function click(Request $request, int $id): Response
    {
        $recommendation = $request->user()->recommendations()->findOrFail($id);
        $recommendation->clicked_at ??= now();
        $recommendation->save();

        return response()->noContent();
    }
}
