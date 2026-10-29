<?php

namespace App\Http\Requests;

use App\Services\SettingService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreTransactionRequest extends FormRequest
{
    public function rules(): array
    {
        $isTopup = $this->input('type') === 'topup';
        $topupAmounts = collect(app(SettingService::class)->get('topup.options'))->pluck('amount')->all();

        return [
            'type' => ['required', 'in:package,topup'],
            'package_id' => ['required_if:type,package', 'prohibited_if:type,topup', 'nullable', 'integer'],
            'topup_amount' => ['required_if:type,topup', 'prohibited_if:type,package', 'nullable', 'integer', Rule::in($topupAmounts)],
            // FR-12.1: tukar poin hanya untuk paket. Aturan kelipatan dan batas dicek TransactionService (POINTS_INVALID).
            'points_used' => ['nullable', 'integer', 'min:0', 'prohibited_if:type,topup'],
            // FR-4.2: isi ulang tidak bisa dibayar dengan pulsa.
            'payment_method' => ['required', Rule::in($isTopup ? ['ewallet', 'va', 'qris'] : ['pulsa', 'ewallet', 'va', 'qris'])],
            'recommendation_id' => ['nullable', 'integer', 'prohibited_if:type,topup',
                Rule::exists('recommendations', 'id')->where('user_id', $this->user()->id)],
        ];
    }

    public function messages(): array
    {
        return [
            'topup_amount.in' => 'Nominal isi ulang tidak tersedia.',
            'payment_method.in' => 'Metode pembayaran tidak tersedia untuk transaksi ini.',
        ];
    }
}
