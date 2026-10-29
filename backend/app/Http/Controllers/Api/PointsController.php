<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DailyEvaluation;
use App\Models\PointLedger;
use App\Models\Transaction;
use App\Services\PointService;
use App\Services\SettingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Carbon;

class PointsController extends Controller
{
    private const CALENDAR_DAYS = 30;

    private const EXPIRING_WITHIN_DAYS = 7;

    /** GET /points (FR-11.7). */
    public function show(Request $request, PointService $points, SettingService $settings): JsonResponse
    {
        $user = $request->user();

        $evaluations = $user->dailyEvaluations()
            ->where('eval_date', '>=', today()->subDays(self::CALENDAR_DAYS))
            ->with('pointLedger')
            ->get()
            ->keyBy(fn ($e) => $e->eval_date->toDateString());

        $calendar = [];
        for ($i = self::CALENDAR_DAYS; $i >= 1; $i--) {
            $date = today()->subDays($i)->toDateString();
            $evaluation = $evaluations[$date] ?? null;
            $calendar[] = [
                'date' => $date,
                // Hari tanpa evaluasi (tidak punya paket aktif) ditampilkan abu-abu seperti no_data.
                'result' => $evaluation?->result ?? 'no_data',
                'points' => (int) ($evaluation?->pointLedger->sum('delta') ?? 0),
            ];
        }

        $expiring = PointLedger::where('user_id', $user->id)
            ->where('remaining', '>', 0)
            ->whereBetween('expires_at', [now(), now()->addDays(self::EXPIRING_WITHIN_DAYS)]);

        return response()->json(['data' => [
            'balance' => $points->balance($user),
            'held' => $points->held($user),
            'streak' => (int) ($user->dailyEvaluations()->latest('eval_date')->value('streak_after') ?? 0),
            'expiring_soon' => (clone $expiring)->exists() ? [
                'points' => (int) (clone $expiring)->sum('remaining'),
                'first_expires_at' => Carbon::parse((clone $expiring)->min('expires_at'))->toDateString(),
            ] : null,
            'calendar' => $calendar,
            'rules' => [
                'points_per_day' => $settings->int('reward.points_per_day'),
                'streak_bonus' => $settings->int('reward.streak_bonus'),
                'streak_length' => $settings->int('reward.streak_length'),
                'min_usage_bytes' => $settings->int('reward.min_usage_bytes'),
            ],
        ]]);
    }

    /** GET /points/ledger (FR-11.7, US-16), terbaru di atas. */
    public function ledger(Request $request): AnonymousResourceCollection
    {
        $page = PointLedger::where('user_id', $request->user()->id)->latest('id')->paginate(20);

        $evaluations = DailyEvaluation::whereIn('id', $page->where('ref_type', 'daily_evaluations')->pluck('ref_id'))->pluck('eval_date', 'id');
        $transactions = Transaction::with('package')->whereIn('id', $page->where('ref_type', 'transactions')->pluck('ref_id'))->get()->keyBy('id');

        $page->through(fn (PointLedger $row) => [
            'id' => $row->id,
            'delta' => $row->delta,
            'type' => $row->type,
            'description' => match ($row->type) {
                'earn_daily' => 'Hari hemat '.Carbon::parse($evaluations[$row->ref_id] ?? $row->created_at)->locale('id')->translatedFormat('j M'),
                'earn_streak' => 'Bonus hari hemat berturut-turut',
                'redeem_hold' => 'Diskon '.($transactions[$row->ref_id]->package->name ?? 'paket'),
                'redeem_release' => 'Poin dikembalikan: pembayaran '.(($transactions[$row->ref_id]->status ?? '') === 'expired' ? 'kedaluwarsa' : 'gagal'),
                'spend_share' => 'Bagi kuota',
                'expire' => 'Poin kedaluwarsa',
                default => $row->type,
            },
            'ref' => $row->ref_type ? ['type' => rtrim($row->ref_type, 's'), 'id' => $row->ref_id] : null,
            'expires_at' => $row->expires_at?->toIso8601String(),
            'created_at' => $row->created_at->toIso8601String(),
        ]);

        // Bentuk {data, links, meta} sama dengan GET /transactions.
        return JsonResource::collection($page);
    }
}
