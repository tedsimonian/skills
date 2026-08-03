# Inngest Workflow Testing Reference

Inngest functions are durable, step-based workflows. Their execution model (step checkpoints, independent retries) creates unique testing needs across three layers.

## Three Layers

| Layer | Tool | Speed | What it Tests |
|-------|------|-------|---------------|
| **Unit** | `@inngest/test` (InngestTestEngine) | ~ms | Step execution, output, order, state, error paths |
| **Integration** | Inngest Dev Server + Vitest | ~seconds | Event routing, multi-step orchestration, retries, cross-function invoke |
| **Monitoring** | Checkly API checks / Heartbeats | Ongoing | Production workflow health |

## Layer 1: Unit Tests with `@inngest/test`

Standard `.test.ts` files, colocated with function files. No infrastructure needed.

```
src/inngest/functions/
├── onboarding-drip.ts
├── onboarding-drip.test.ts       ← InngestTestEngine tests
├── process-payment.ts
└── process-payment.test.ts
```

**Core API:**
- `t.execute()` - runs entire function, returns `{ result, ctx, state }`
- `t.executeStep("step-id")` - runs until a specific step checkpoint

**What to test:**
- Full execution → assert on final `result`, verify all steps via `state`
- Individual step outputs → `t.executeStep("calculate-price")` → assert `result`
- Step invocation order → `ctx.step.run` is a spy: `toHaveBeenCalledWith("step-id", expect.any(Function))`
- State across steps → `state["step-id"]` resolves to step's output
- Error paths → `state["dangerous-step"]` → `rejects.toThrowError("something failed")`

**Mocking:**
- Events: `t.execute({ events: [{ name: "user/signup", data: { email: "test@test.com" } }] })`
- Steps: `t.execute({ steps: [{ id: "fetch-user", handler() { return mockUser; } }] })`
- Context: `transformCtx` for middleware context, mocked services
- Cloning: `t.clone({ /* additional mocks */ })` for base fixture patterns

**Behavioral nuances:**
- `step.sleep` / `step.sleep_until` resolve immediately (0ms)
- `step.send_event` is stubbed - assert on `ctx.step.sendEvent` spy
- `step.invoke` / `step.waitForEvent` **must** be stubbed via step mocks
- Retries are NOT modeled - failures throw immediately (test retries at integration layer)
- External module mocking uses `vi.mock()`, not `@inngest/test`

## Layer 2: Integration Tests with Dev Server

`.integration.test.ts` in `tests/integration/`. Verifies full event-driven pipeline.

**Dev Server startup:**
```bash
npx inngest-cli@latest dev --no-discovery -u http://localhost:${API_PORT}/api/inngest
```

**What to test:** Event routing, multi-step orchestration, retry behavior, concurrency/throttling, cross-function `step.invoke`.

**Config:** `testTimeout: 30_000` (polling for async events). `INNGEST_DEV=1`, `INNGEST_EVENT_KEY=test`, `INNGEST_SIGNING_KEY=test`.

**Critical pitfall:** Do NOT hold database transactions across `await step.run()` boundaries. The Dev Server replays from the beginning on each step invocation.

**CI startup:**
```bash
npx inngest-cli@latest dev --no-discovery -u http://localhost:4000/api/inngest &
until curl -sf http://localhost:8288/health > /dev/null; do sleep 1; done
```

## Layer 3: Production Monitoring

Checkly API checks that exercise triggering endpoints and verify downstream effects. For long-running/cron functions, use Checkly Heartbeat checks (final step pings heartbeat URL on success).

**Monitor:** Serve endpoint returns 200, critical workflows produce expected outcomes, heartbeat signals from cron functions.

## Rules

**DO:** Start with unit tests for all functions. Use `t.clone()` for base fixtures. Extract pure logic from step handlers into testable helpers. Assert spy calls for `step.sendEvent`/`step.invoke`.

**DON'T:** Skip unit tests for integration. Hold transactions across step boundaries. Forget to start Dev Server before CI integration tests. Test the Inngest SDK itself.
