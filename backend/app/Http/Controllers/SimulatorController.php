<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Services\PaymentService;
use App\Services\TransactionService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Http;
use Illuminate\View\View;

/**
 * Halaman simulator bank / e-wallet (FR-5.4). Mewakili aplikasi bank di luar Kuota+, jadi hasilnya dikirim
 * ke server lewat callback HTTP sungguhan yang ditandatangani, bukan dengan memanggil service langsung.
 */
class SimulatorController extends Controller
{
    private const METHOD_LABELS = ['ewallet' => 'E-Wallet', 'va' => 'Virtual Account', 'qris' => 'QRIS'];

    public function show(string $externalRef): View
    {
        $transaction = Transaction::with('package')->where('external_ref', $externalRef)->firstOrFail();

        return view('simulator', [
            'transaction' => $transaction,
            'itemName' => $transaction->package?->name ?? 'Isi ulang '.TransactionService::rupiah($transaction->topup_amount),
            'amount' => TransactionService::rupiah($transaction->net_amount),
            'methodLabel' => self::METHOD_LABELS[$transaction->payment_method] ?? $transaction->payment_method,
        ]);
    }

    public function pay(string $externalRef): RedirectResponse
    {
        return $this->sendCallback($externalRef, 'PAID');
    }

    public function reject(string $externalRef): RedirectResponse
    {
        return $this->sendCallback($externalRef, 'FAILED');
    }

    private function sendCallback(string $externalRef, string $status): RedirectResponse
    {
        $body = json_encode(['external_ref' => $externalRef, 'status' => $status, 'paid_at' => now()->toIso8601String()]);

        $response = Http::withBody($body, 'application/json')
            ->withHeaders(['X-Signature' => PaymentService::sign($body), 'Accept' => 'application/json'])
            ->timeout(15)
            ->post(rtrim(config('app.url'), '/').'/api/payments/callback');

        $message = match (true) {
            $response->successful() && $status === 'PAID' => ['ok', 'Pembayaran berhasil. Kembali ke aplikasi Kuota+.'],
            $response->successful() => ['ok', 'Pembayaran ditolak. Kembali ke aplikasi Kuota+.'],
            $response->status() === 409 => ['error', 'Transaksi sudah kedaluwarsa.'],
            default => ['error', 'Terjadi gangguan. Coba lagi.'],
        };

        return redirect()->route('simulator.show', $externalRef)->with('result', $message);
    }
}
