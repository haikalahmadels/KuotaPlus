<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Simulator Pembayaran</title>
    <style>
        :root { --primary: #1E40AF; --text: #111827; --muted: #4B5563; --border: #E5E7EB; --bg: #F6F7F9;
                --success: #15803D; --danger: #B91C1C; --warning: #B45309; }
        * { box-sizing: border-box; }
        body { margin: 0; padding: 16px; background: var(--bg); color: var(--text);
               font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
        main { max-width: 420px; margin: 0 auto; }
        .tag { display: inline-block; padding: 2px 10px; border: 1px solid var(--warning); border-radius: 999px;
               color: var(--warning); font-size: 12px; font-weight: 700; }
        .card { background: #fff; border: 1px solid var(--border); border-radius: 16px; padding: 16px; margin: 16px 0; }
        .muted { color: var(--muted); }
        .amount { font-size: 32px; font-weight: 700; margin: 4px 0 12px; }
        dl { display: grid; grid-template-columns: auto 1fr; gap: 4px 12px; margin: 0; }
        dt { color: var(--muted); } dd { margin: 0; text-align: right; word-break: break-all; }
        .result { padding: 12px; border-radius: 12px; border: 1px solid; margin: 16px 0; }
        .result.ok { border-color: var(--success); color: var(--success); }
        .result.error { border-color: var(--danger); color: var(--danger); }
        button { width: 100%; min-height: 48px; border-radius: 12px; font: inherit; font-weight: 600; cursor: pointer; }
        .pay { background: var(--primary); color: #fff; border: 0; margin-bottom: 12px; }
        .reject { background: #fff; color: var(--danger); border: 1px solid var(--danger); }
    </style>
</head>
<body>
<main>
    <span class="tag">SIMULATOR</span>
    <h1>{{ $methodLabel }}</h1>
    <p class="muted">Halaman ini menggantikan aplikasi bank atau e-wallet. Tidak ada uang sungguhan yang berpindah.</p>

    @if (session('result'))
        <div class="result {{ session('result')[0] }}" role="status">{{ session('result')[1] }}</div>
    @endif

    <section class="card">
        <div class="muted">Total bayar</div>
        <div class="amount">{{ $amount }}</div>
        <dl>
            <dt>Item</dt><dd>{{ $itemName }}</dd>
            <dt>Referensi</dt><dd>{{ $transaction->external_ref }}</dd>
            <dt>Status</dt><dd>{{ strtoupper($transaction->status) }}</dd>
            @if ($transaction->expires_at)
                <dt>Bayar sebelum</dt><dd>{{ $transaction->expires_at->format('d M Y, H.i') }} WIB</dd>
            @endif
        </dl>
    </section>

    @if ($transaction->status === 'pending')
        <form method="post" action="{{ route('simulator.pay', $transaction->external_ref) }}">
            @csrf
            <button class="pay" type="submit">Bayar</button>
        </form>
        <form method="post" action="{{ route('simulator.reject', $transaction->external_ref) }}">
            @csrf
            <button class="reject" type="submit">Tolak</button>
        </form>
    @endif
</main>
</body>
</html>
