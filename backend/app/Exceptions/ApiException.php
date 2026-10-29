<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;

/**
 * Error bisnis dengan `code` stabil sesuai docs/API-KuotaPlus.md (Lampiran A).
 */
class ApiException extends Exception
{
    public function __construct(
        public readonly int $status,
        public readonly string $errorCode,
        string $message,
        public readonly array $meta = [],
    ) {
        parent::__construct($message);
    }

    public function render(): JsonResponse
    {
        return self::json($this->status, $this->errorCode, $this->getMessage(), meta: $this->meta);
    }

    public static function json(int $status, string $code, string $message, array $errors = [], array $meta = []): JsonResponse
    {
        return response()->json(array_filter([
            'message' => $message,
            'code' => $code,
            'errors' => $errors,
            'meta' => $meta,
        ], fn ($value) => $value !== []), $status);
    }
}
