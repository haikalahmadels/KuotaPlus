<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\QuotaTransferResource;
use App\Services\QuotaTransferService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Str;

/** Berbagi kuota (FR-14): quote → OTP → eksekusi, dan riwayat sebagai pengirim. */
class QuotaTransferController extends Controller
{
    public function __construct(private QuotaTransferService $transfers) {}

    /** GET /quota-transfers/quote */
    public function quote(Request $request): JsonResponse
    {
        $validated = $request->validate(['recipient_msisdn' => ['required', 'string', 'max:20']]);
        $recipient = $this->transfers->recipient($request->user(), $validated['recipient_msisdn']);

        return response()->json(['data' => $this->transfers->quote($request->user(), $recipient)]);
    }

    /** POST /quota-transfers/otp */
    public function otp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'recipient_msisdn' => ['required', 'string', 'max:20'],
            'bytes' => ['required', 'integer', 'min:1'],
        ]);
        $sent = $this->transfers->requestOtp($request->user(), $validated['recipient_msisdn'], $validated['bytes']);

        return response()->json(['data' => array_filter([
            'expires_at' => $sent['expires_at']->toIso8601String(),
            'resend_available_at' => $sent['resend_available_at']->toIso8601String(),
            'demo_otp' => config('services.otp.expose_code') ? $sent['code'] : null,
        ], fn ($value) => $value !== null)]);
    }

    /** POST /quota-transfers (Idempotency-Key wajib) */
    public function store(Request $request): JsonResponse
    {
        $key = $request->header('Idempotency-Key');
        if (! is_string($key) || ! Str::isUuid($key)) {
            throw new ApiException(400, 'IDEMPOTENCY_KEY_REQUIRED', 'Header Idempotency-Key (UUID) wajib dikirim.');
        }
        $validated = $request->validate([
            'recipient_msisdn' => ['required', 'string', 'max:20'],
            'bytes' => ['required', 'integer', 'min:1'],
            'otp_code' => ['required', 'digits:6'],
        ]);

        $user = $request->user();
        [$transfer, $created] = $this->transfers->execute(
            $user, $validated['recipient_msisdn'], $validated['bytes'], $validated['otp_code'], $key,
        );

        $resource = new QuotaTransferResource($transfer->load('recipient'));
        $resource->senderRemainingAfter = $this->transfers->senderRemaining($user);

        return $resource->response()->setStatusCode($created ? 201 : 200);
    }

    /** GET /quota-transfers: riwayat sebagai pengirim, terbaru di atas. */
    public function index(Request $request): AnonymousResourceCollection
    {
        return QuotaTransferResource::collection(
            $request->user()->quotaTransfers()->with('recipient')->latest('id')->paginate(20),
        );
    }
}
