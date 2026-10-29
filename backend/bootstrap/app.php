<?php

use App\Exceptions\ApiException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->throttleApi();
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // Semua error /api/* memakai format { message, code, errors?, meta? } (docs/API-KuotaPlus.md).
        $exceptions->render(function (Throwable $e, Request $request) {
            if (! $request->is('api/*') || $e instanceof ApiException) {
                return null;
            }

            return match (true) {
                $e instanceof ValidationException => ApiException::json(422, 'VALIDATION_FAILED', $e->getMessage(), $e->errors()),
                $e instanceof AuthenticationException => ApiException::json(401, 'UNAUTHENTICATED', 'Sesi berakhir. Silakan masuk lagi.'),
                $e instanceof ThrottleRequestsException => ApiException::json(429, 'TOO_MANY_REQUESTS', 'Terlalu banyak permintaan. Coba lagi sebentar.',
                    meta: ['retry_after' => (int) ($e->getHeaders()['Retry-After'] ?? 60)]),
                $e instanceof ModelNotFoundException, $e instanceof NotFoundHttpException => ApiException::json(404, 'NOT_FOUND', 'Data tidak ditemukan.'),
                $e instanceof HttpExceptionInterface => ApiException::json($e->getStatusCode(), 'HTTP_'.$e->getStatusCode(), 'Permintaan tidak dapat diproses.'),
                // Detail error hanya di log, tidak dikirim ke client.
                default => ApiException::json(500, 'SERVER_ERROR', 'Terjadi kesalahan di server. Coba lagi.'),
            };
        });
    })->create();
