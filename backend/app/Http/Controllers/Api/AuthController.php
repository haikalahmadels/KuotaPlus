<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\OtpRequestRequest;
use App\Http\Requests\OtpVerifyRequest;
use App\Models\Subscriber;
use App\Services\OtpService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * FR-1: login nomor HP + OTP dummy, token Sanctum.
 */
class AuthController extends Controller
{
    public function __construct(private OtpService $otp) {}

    public function requestOtp(OtpRequestRequest $request): JsonResponse
    {
        $msisdn = $this->loginableSubscriber($request->msisdn())->msisdn;
        $sent = $this->otp->send($msisdn, 'login');

        return response()->json(['data' => array_filter([
            'msisdn' => $msisdn,
            'expires_at' => $sent['expires_at']->toIso8601String(),
            'resend_available_at' => $sent['resend_available_at']->toIso8601String(),
            'demo_otp' => config('services.otp.expose_code') ? $sent['code'] : null,
        ], fn ($value) => $value !== null)]);
    }

    public function verifyOtp(OtpVerifyRequest $request): JsonResponse
    {
        $subscriber = $this->loginableSubscriber($request->msisdn());
        $this->otp->verify($subscriber->msisdn, 'login', $request->validated('code'));

        // Akun dibuat otomatis pada login pertama.
        $user = $subscriber->user()->firstOrCreate([]);
        $user->update(['last_login_at' => now()]);

        return response()->json(['data' => [
            'token' => $user->createToken($request->validated('device_name') ?? 'kuotaplus')->plainTextToken,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'msisdn' => $subscriber->msisdn,
            ],
        ]]);
    }

    public function logout(Request $request): Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    private function loginableSubscriber(string $msisdn): Subscriber
    {
        $subscriber = Subscriber::where('msisdn', $msisdn)->first()
            ?? throw new ApiException(404, 'NOT_SUBSCRIBER', 'Nomor bukan pelanggan Nusantel.');

        if ($subscriber->status === 'terminated') {
            throw new ApiException(403, 'SUBSCRIBER_TERMINATED', 'Nomor ini sudah tidak aktif karena masa tenggang telah berakhir.');
        }

        return $subscriber;
    }
}
