"""Seed Tempo (OTLP/HTTP, default 127.0.0.1:4328) with spans over the last ~30 min carrying long-ish attribute values."""
import json, os, random, time, urllib.request
EP = f"http://127.0.0.1:{os.environ.get('TEMPO_OTLP_PORT','4328')}/v1/traces"
SVCS = ["checkout-orchestration-service-eu-west", "payment-authorization-gateway-primary",
        "inventory-reservation-worker-canary", "notification-dispatch-fanout-service"]
ROUTES = ["/api/v2/checkout/sessions/{sessionId}/confirm-payment", "/api/v2/inventory/reservations/{reservationId}/extend",
          "/internal/notifications/batch-dispatch/{channel}", "/api/v2/payments/authorizations/{authId}/capture"]
REGIONS = ["eu-west-1-availability-zone-b-production", "us-east-2-availability-zone-a-production", "ap-southeast-1-zone-c-staging"]
def kv(k, v): return {"key": k, "value": {"intValue": v} if isinstance(v, int) else {"stringValue": v}}
def rid(n): return os.urandom(n).hex()
now = time.time_ns()
for batch in range(30):
    rs = []
    for svc in SVCS:
        spans = []
        for i in range(25):
            st = now - random.randint(0, 29 * 60) * 10**9
            dur = int(random.lognormvariate(17, 1.0))
            err = random.random() < 0.15
            spans.append({"traceId": rid(16), "spanId": rid(8), "name": "HTTP " + random.choice(["GET", "POST"]) + " " + random.choice(ROUTES),
                "kind": 2, "startTimeUnixNano": str(st), "endTimeUnixNano": str(st + dur),
                "attributes": [kv("http.route", random.choice(ROUTES)), kv("http.request.method", random.choice(["GET", "POST"])),
                    kv("http.response.status_code", 500 if err else 200), kv("deployment.region", random.choice(REGIONS))],
                "status": {"code": 2 if err else 1}})
        rs.append({"resource": {"attributes": [kv("service.name", svc), kv("service.namespace", "ridesharing-production"),
            kv("k8s.cluster.name", random.choice(REGIONS))]}, "scopeSpans": [{"scope": {"name": "seed"}, "spans": spans}]})
    req = urllib.request.Request(EP, json.dumps({"resourceSpans": rs}).encode(), {"Content-Type": "application/json"})
    for attempt in range(10):
        try:
            urllib.request.urlopen(req, timeout=60).read(); break
        except Exception as e:
            print("retry", batch, e); time.sleep(5)
print("seeded", 30 * len(SVCS) * 25, "spans")
