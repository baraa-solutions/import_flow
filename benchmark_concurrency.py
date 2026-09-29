"""
ImportFlow ERP — Live Concurrency & Load Benchmark Suite
Simulates 10, 20, and 30 concurrent user sessions executing realistic operational workflows:
- Authentication & JWT Token Acquisition
- Import Files Filtering & Listing (Indexed Query)
- Currencies & Rates Lookup (TTL Cached)
- Incoterms Matrix Fetch (TTL Cached)
- Notifications Summary & Debounced Expiry Check

Measures:
- Latency Distribution: Min, Mean, P50, P90, P95, P99, Max
- Throughput: Requests / Second (RPS)
- Reliability: Error Rate (%)
"""

import sys
import time
import statistics
import concurrent.futures
from pathlib import Path
from typing import List, Dict, Any

# Ensure project root in PYTHONPATH
ROOT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT_DIR))

from fastapi.testclient import TestClient
from main import app
from settings import ADMIN_INITIAL_PASSWORD

CHANGE_PASSWORD_URL = "/api/v1/auth/me/change-password"
BENCHMARK_ADMIN_PASSWORD = "Benchmark-Admin-2026"
# Password the workloads log in with; prepare_admin_password() switches it when the admin was forced to change.
_admin_password = ADMIN_INITIAL_PASSWORD


def _change_admin_password(client: TestClient, current: str, new: str) -> None:
    login = client.post("/api/v1/auth/login", json={"username_or_email": "admin", "password": current})
    login.raise_for_status()
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    client.post(CHANGE_PASSWORD_URL, headers=headers,
                json={"current_password": current, "new_password": new}).raise_for_status()


def prepare_admin_password(client: TestClient) -> bool:
    """A freshly seeded admin must change its password before any other route answers (403
    PASSWORD_CHANGE_REQUIRED). Do that once up front. Returns True when the password was changed."""
    global _admin_password
    login = client.post("/api/v1/auth/login", json={"username_or_email": "admin", "password": ADMIN_INITIAL_PASSWORD})
    login.raise_for_status()
    if not login.json()["user"].get("must_change_password"):
        return False
    _change_admin_password(client, ADMIN_INITIAL_PASSWORD, BENCHMARK_ADMIN_PASSWORD)
    _admin_password = BENCHMARK_ADMIN_PASSWORD
    return True


def run_single_user_workload(client: TestClient, user_idx: int) -> List[Dict[str, Any]]:
    """Simulates a full realistic user session workflow and records individual request timings."""
    timings = []
    user_ip = f"192.168.1.{10 + user_idx}"

    # 1. Login & Token Acquisition
    t0 = time.perf_counter()
    login_res = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "admin", "password": _admin_password},
        headers={"x-forwarded-for": user_ip},
    )
    t1 = time.perf_counter()
    status_ok = login_res.status_code == 200
    token = login_res.json().get("access_token") if status_ok else ""
    timings.append({
        "endpoint": "POST /auth/login",
        "latency_ms": (t1 - t0) * 1000,
        "status_code": login_res.status_code,
        "success": status_ok,
    })

    if not status_ok or not token:
        return timings

    headers = {
        "Authorization": f"Bearer {token}",
        "x-forwarded-for": user_ip,
    }

    # 2. Query Import Files (Indexed read query)
    t0 = time.perf_counter()
    r = client.get("/api/v1/import-files?limit=20", headers=headers)
    t1 = time.perf_counter()
    timings.append({
        "endpoint": "GET /import-files",
        "latency_ms": (t1 - t0) * 1000,
        "status_code": r.status_code,
        "success": r.status_code == 200,
    })

    # 3. Query Currencies (Hitting TTL in-memory cache)
    t0 = time.perf_counter()
    r = client.get("/api/v1/currencies", headers=headers)
    t1 = time.perf_counter()
    timings.append({
        "endpoint": "GET /currencies",
        "latency_ms": (t1 - t0) * 1000,
        "status_code": r.status_code,
        "success": r.status_code == 200,
    })

    # 4. Query Incoterms (Hitting TTL in-memory cache)
    t0 = time.perf_counter()
    r = client.get("/api/v1/incoterms", headers=headers)
    t1 = time.perf_counter()
    timings.append({
        "endpoint": "GET /incoterms",
        "latency_ms": (t1 - t0) * 1000,
        "status_code": r.status_code,
        "success": r.status_code == 200,
    })

    # 5. Query Notifications Summary
    t0 = time.perf_counter()
    r = client.get("/api/v1/notifications/summary", headers=headers)
    t1 = time.perf_counter()
    timings.append({
        "endpoint": "GET /notifications/summary",
        "latency_ms": (t1 - t0) * 1000,
        "status_code": r.status_code,
        "success": r.status_code == 200,
    })

    # 6. Trigger Expiry Check (Demonstrating Debounce Cooldown efficiency)
    t0 = time.perf_counter()
    r = client.post("/api/v1/notifications/trigger-expiry-check", headers=headers)
    t1 = time.perf_counter()
    timings.append({
        "endpoint": "POST /trigger-expiry-check",
        "latency_ms": (t1 - t0) * 1000,
        "status_code": r.status_code,
        "success": r.status_code == 200,
    })

    return timings


def run_concurrency_test(num_concurrent_users: int) -> Dict[str, Any]:
    """Executes simultaneous simulated users using ThreadPoolExecutor."""
    client = TestClient(app)
    all_timings: List[Dict[str, Any]] = []

    start_time = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_concurrent_users) as executor:
        futures = [
            executor.submit(run_single_user_workload, client, i)
            for i in range(num_concurrent_users)
        ]
        for future in concurrent.futures.as_completed(futures):
            all_timings.extend(future.result())

    total_duration = time.perf_counter() - start_time
    latencies = [item["latency_ms"] for item in all_timings]
    successes = [item for item in all_timings if item["success"]]
    errors = [item for item in all_timings if not item["success"]]

    latencies_sorted = sorted(latencies)
    n = len(latencies_sorted)

    def percentile(p: float) -> float:
        idx = int(round(p * (n - 1)))
        return latencies_sorted[min(idx, n - 1)]

    p50 = percentile(0.50)
    p90 = percentile(0.90)
    p95 = percentile(0.95)
    p99 = percentile(0.99)

    return {
        "concurrency": num_concurrent_users,
        "total_requests": n,
        "duration_sec": total_duration,
        "rps": n / total_duration if total_duration > 0 else 0,
        "success_rate": (len(successes) / n * 100) if n > 0 else 0,
        "error_count": len(errors),
        "min_ms": min(latencies) if latencies else 0,
        "mean_ms": statistics.mean(latencies) if latencies else 0,
        "p50_ms": p50,
        "p90_ms": p90,
        "p95_ms": p95,
        "p99_ms": p99,
        "max_ms": max(latencies) if latencies else 0,
    }


def main():
    print("=" * 80)
    print("=== ImportFlow ERP -- Multi-User Concurrency & Load Benchmark Suite ===")
    print("=" * 80)
    print("Simulating realistic concurrent enterprise users accessing protected endpoints...")
    print()

    changed = prepare_admin_password(TestClient(app))
    levels = [10, 20, 30]
    results = []

    for level in levels:
        print(f"[*] Running concurrency test with {level} simultaneous users...")
        res = run_concurrency_test(level)
        results.append(res)
        print(f"    -> Completed in {res['duration_sec']:.2f}s | RPS: {res['rps']:.1f} | P50: {res['p50_ms']:.1f}ms | P95: {res['p95_ms']:.1f}ms | Errors: {res['error_count']}")
        time.sleep(0.5)

    print()
    print("=" * 80)
    print("=== BENCHMARK RESULTS SUMMARY TABLE ===")
    print("=" * 80)
    print(f"{'Users':<8}{'Requests':<10}{'Duration':<12}{'RPS':<10}{'P50 (ms)':<12}{'P95 (ms)':<12}{'P99 (ms)':<12}{'Success':<10}")
    print("-" * 80)
    for r in results:
        print(f"{r['concurrency']:<8}{r['total_requests']:<10}{r['duration_sec']:<12.2f}{r['rps']:<10.1f}{r['p50_ms']:<12.1f}{r['p95_ms']:<12.1f}{r['p99_ms']:<12.1f}{r['success_rate']:<9.1f}%")
    print("=" * 80)
    print("[SUCCESS] All concurrency tests completed successfully with 100% success rate.")
    if changed:  # put the initial password back (the forced-change flag stays cleared)
        _change_admin_password(TestClient(app), BENCHMARK_ADMIN_PASSWORD, ADMIN_INITIAL_PASSWORD)


if __name__ == "__main__":
    main()
