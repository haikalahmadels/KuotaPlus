"""Skenario demo untuk DoD "Performa lokal" (p95 latensi API <= 500 ms).

Login akun demo Budi, lalu membuka layar-layar aplikasi berulang kali seperti saat demo:
beranda, katalog, analisis, detail aplikasi, rekomendasi, reward, riwayat, isi ulang, berbagi.
Satu transaksi QRIS pending dibuat untuk mengukur endpoint tulis (kedaluwarsa sendiri).
Jeda 1,25 detik antar-request supaya di bawah batas 60 request/menit per pengguna.

Pemakaian: python perf_api.py [base_url] [putaran]
Angka sisi klien dicetak di sini; angka sisi server dibaca dari Telescope (perf_telescope.php).
"""
import json
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://192.168.1.2/api"
ROUNDS = int(sys.argv[2]) if len(sys.argv) > 2 else 15
BUDI = "6288100000002"
ANDI = "6288100000007"


def call(method, path, token=None, body=None, headers=None):
    req = urllib.request.Request(BASE + path, method=method, data=None if body is None else json.dumps(body).encode())
    req.add_header("Accept", "application/json")
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            data, status = json.loads(res.read() or b"{}"), res.status
    except urllib.error.HTTPError as e:
        data, status = json.loads(e.read() or b"{}"), e.code
    return data, status, (time.perf_counter() - start) * 1000


def p95(values):
    s = sorted(values)
    return s[max(0, int(round(0.95 * len(s))) - 1)]


def main():
    code = call("POST", "/auth/otp/request", body={"msisdn": BUDI})[0]["data"]["demo_otp"]
    token = call("POST", "/auth/otp/verify", body={"msisdn": BUDI, "code": code, "device_name": "perf"})[0]["data"]["token"]

    summary = call("GET", "/usage/summary?period=7d", token)[0]["data"]
    app_id = summary["apps"][0]["app_id"] if summary.get("apps") else None
    catalog = call("GET", "/packages", token)[0]["data"]
    cheapest = min((p for g in catalog["groups"] for p in g["packages"]), key=lambda p: p["price"])

    paths = [
        "/home", "/packages", "/usage/summary?period=7d", "/usage/summary?period=30d",
        "/recommendations", "/points", "/points/ledger", "/transactions", "/topup-options",
        "/quota-transfers", f"/quota-transfers/quote?recipient_msisdn={ANDI}",
    ]
    if app_id:
        paths.append(f"/usage/apps/{app_id}?period=7d")

    timings, errors = {}, []
    for r in range(ROUNDS):
        for path in paths:
            data, status, ms = call("GET", path, token)
            key = path.split("?")[0] if "summary" not in path else path
            timings.setdefault(key, []).append(ms)
            if status != 200:
                errors.append((path, status))
            time.sleep(1.25)
        if r == 0:
            tx, status, ms = call("POST", "/transactions", token,
                                  {"type": "package", "package_id": cheapest["id"], "payment_method": "qris"},
                                  {"Idempotency-Key": str(uuid.uuid4())})
            timings.setdefault("POST /transactions", []).append(ms)
            if status not in (200, 201):
                errors.append(("POST /transactions", status))
            else:
                _, status, ms = call("GET", f"/transactions/{tx['data']['id']}", token)
                timings.setdefault("/transactions/{id}", []).append(ms)
        print(f"putaran {r + 1}/{ROUNDS} selesai", flush=True)

    every = [v for vs in timings.values() for v in vs]
    print(f"\n{'endpoint':38} {'n':>3} {'median':>8} {'p95':>8} {'maks':>8}")
    for key, vs in timings.items():
        print(f"{key:38} {len(vs):3} {sorted(vs)[len(vs) // 2]:8.0f} {p95(vs):8.0f} {max(vs):8.0f}")
    print(f"\nSemua request: n={len(every)}, p95 klien = {p95(every):.0f} ms, maks = {max(every):.0f} ms")
    print("Error:", errors or "tidak ada")


if __name__ == "__main__":
    main()
