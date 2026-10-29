<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SubscriberResource;
use App\Http\Resources\SubscriptionResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class HomeController extends Controller
{
    /**
     * GET /home (FR-2). forecast, daily_budget, recommendation_teaser diisi di M5; alerts di M7.
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        $subscriber = $user->subscriber;

        $subscriptions = $subscriber->subscriptions()
            ->current()
            ->with(['package', 'incomingTransfer.sender.subscriber'])
            ->get();

        $latestUsage = $user->usageRecords()->latest('synced_at')->first(['source', 'synced_at']);

        return response()->json(['data' => [
            'server_time' => now()->toIso8601String(),
            'subscriber' => new SubscriberResource($subscriber),
            'subscriptions' => SubscriptionResource::collection($subscriptions),
            'forecast' => null,
            'daily_budget' => null,
            'recommendation_teaser' => null,
            'points' => [
                'balance' => $user->pointBalance(),
                'streak' => $user->dailyEvaluations()->latest('eval_date')->value('streak_after') ?? 0,
            ],
            'usage' => [
                'source' => $latestUsage?->source,
                'last_synced_at' => $latestUsage?->synced_at->toIso8601String(),
            ],
            'alerts' => [],
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
