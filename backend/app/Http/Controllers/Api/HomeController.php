<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ForecastResource;
use App\Http\Resources\SubscriberResource;
use App\Http\Resources\SubscriptionResource;
use App\Services\AlertService;
use App\Services\ForecastService;
use App\Services\RecommendationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class HomeController extends Controller
{
    /**
     * GET /home (FR-2, FR-9, FR-10, FR-13).
     */
    public function show(
        Request $request,
        ForecastService $forecasts,
        RecommendationService $recommendations,
        AlertService $alerts,
    ): JsonResponse
    {
        $user = $request->user();
        $subscriber = $user->subscriber;

        $subscriptions = $subscriber->subscriptions()
            ->current()
            ->with(['package', 'incomingTransfer.sender.subscriber'])
            ->get();

        $latestUsage = $user->usageRecords()->latest('synced_at')->first(['source', 'synced_at']);
        $forecast = $subscriptions->isEmpty() ? null : $forecasts->latest($user);

        // Teaser hanya jika ada penghematan nyata (FR-2.4).
        $top = $recommendations->current($user)['items']->first();
        $teaser = $top && $top->saving_30d > 0
            ? ['recommendation_id' => $top->id, 'package_name' => $top->package->name, 'saving_30d' => $top->saving_30d]
            : null;

        return response()->json(['data' => [
            'server_time' => now()->toIso8601String(),
            'subscriber' => new SubscriberResource($subscriber),
            'subscriptions' => SubscriptionResource::collection($subscriptions),
            'forecast' => $forecast ? new ForecastResource($forecast) : null,
            'daily_budget' => $forecast ? [
                'budget_bytes' => $forecast->daily_budget_bytes,
                'used_today_bytes' => (int) $user->usageRecords()->whereDate('usage_date', today())->sum('bytes_mobile'),
            ] : null,
            'recommendation_teaser' => $teaser,
            'points' => [
                'balance' => $user->pointBalance(),
                'streak' => $user->dailyEvaluations()->latest('eval_date')->value('streak_after') ?? 0,
            ],
            'usage' => [
                'source' => $latestUsage?->source,
                'last_synced_at' => $latestUsage?->synced_at->toIso8601String(),
            ],
            'alerts' => $alerts->collect($user),
        ]]);
    }

    /** PUT /device: status izin Usage Access untuk metrik admin (FR-15.2). */
    public function device(Request $request): Response
    {
        $validated = $request->validate([
            'platform' => ['required', 'in:android,web'],
            'usage_access_granted' => ['required', 'boolean'],
        ]);

        $request->user()->update($validated + ['usage_access_checked_at' => now()]);

        return response()->noContent();
    }
}
