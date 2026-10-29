<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTransactionRequest;
use App\Http\Resources\TransactionResource;
use App\Http\Resources\TransactionSummaryResource;
use App\Services\PaymentService;
use App\Services\TransactionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Str;

class TransactionController extends Controller
{
    /** POST /transactions (FR-3, FR-4, FR-5). */
    public function store(StoreTransactionRequest $request, TransactionService $transactions): JsonResponse
    {
        $key = $request->header('Idempotency-Key');
        if (! is_string($key) || ! Str::isUuid($key)) {
            throw new ApiException(400, 'IDEMPOTENCY_KEY_REQUIRED', 'Header Idempotency-Key (UUID) wajib dikirim.');
        }

        [$transaction, $created] = $transactions->create($request->user(), $request->validated(), $key);

        return (new TransactionResource($transaction->load(['package', 'subscription'])))
            ->response()
            ->setStatusCode($created ? 201 : 200);
    }

    /** GET /transactions (FR-6.1). */
    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate(['status' => ['nullable', 'in:pending,paid,failed,expired']]);

        $page = $request->user()->transactions()
            ->when($request->query('status'), fn ($query, $status) => $query->where('status', $status))
            ->with('package')
            ->latest('id')
            ->paginate(20);

        return TransactionSummaryResource::collection($page);
    }

    /** GET /transactions/{id} (FR-5.7, FR-6.2). Transaksi milik orang lain = 404. */
    public function show(Request $request, int $id): TransactionResource
    {
        return new TransactionResource($request->user()->transactions()->with(['package', 'subscription'])->findOrFail($id));
    }

    /** POST /payments/callback: dari simulator, ditandatangani HMAC (FR-5.5). */
    public function callback(Request $request, PaymentService $payments): Response
    {
        $payments->handleCallback($request->getContent(), $request->header('X-Signature'));

        return response()->noContent(200);
    }
}
