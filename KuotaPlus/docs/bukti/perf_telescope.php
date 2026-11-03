<?php

/**
 * p95 durasi request API menurut Telescope (DoD "Performa lokal") sejak waktu mulai skenario.
 * Pemakaian (dari folder backend): php ../KuotaPlus/docs/bukti/perf_telescope.php "2026-11-03 16:11:28"
 */

require __DIR__.'/../../../backend/vendor/autoload.php';
$app = require __DIR__.'/../../../backend/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$since = $argv[1] ?? now()->subHour()->toDateTimeString();

$rows = Illuminate\Support\Facades\DB::table('telescope_entries')
    ->where('type', 'request')
    ->where('created_at', '>=', $since)
    ->pluck('content')
    ->map(fn ($c) => json_decode($c, true))
    ->filter(fn ($c) => str_starts_with($c['uri'] ?? '', '/api/'));

$p95 = function (array $v): int {
    sort($v);

    return $v[max(0, (int) round(0.95 * count($v)) - 1)];
};

$byRoute = $rows->groupBy(fn ($c) => $c['method'].' '.preg_replace('/\?.*$/', '', preg_replace('#/\d+(?=/|\?|$)#', '/{id}', $c['uri'])));
printf("%-42s %3s %7s %7s %7s\n", 'endpoint (server, Telescope)', 'n', 'median', 'p95', 'maks');
foreach ($byRoute->sortKeys() as $route => $entries) {
    $d = $entries->pluck('duration')->all();
    sort($d);
    printf("%-42s %3d %7d %7d %7d\n", $route, count($d), $d[intdiv(count($d), 2)], $p95($d), max($d));
}
$all = $rows->pluck('duration')->all();
printf("\nSemua request API: n=%d, p95 server = %d ms, maks = %d ms\n", count($all), $p95($all), max($all));
