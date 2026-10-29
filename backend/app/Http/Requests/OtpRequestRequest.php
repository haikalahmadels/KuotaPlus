<?php

namespace App\Http\Requests;

use App\Models\Subscriber;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class OtpRequestRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'msisdn' => ['required', 'string', 'max:20'],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                if (! $validator->errors()->has('msisdn') && $this->msisdn() === null) {
                    $validator->errors()->add('msisdn', 'Nomor HP tidak valid.');
                }
            },
        ];
    }

    /** Nomor dalam format 628…, null jika tidak valid. */
    public function msisdn(): ?string
    {
        return Subscriber::normalizeMsisdn((string) $this->input('msisdn'));
    }
}
