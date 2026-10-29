<?php

namespace App\Http\Requests;

class OtpVerifyRequest extends OtpRequestRequest
{
    public function rules(): array
    {
        return parent::rules() + [
            'code' => ['required', 'digits:6'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }
}
