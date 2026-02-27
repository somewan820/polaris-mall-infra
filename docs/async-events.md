# Async Event Baseline (I004)

## Scope

This document defines the non-prod async baseline for order and payment event flow.

## Stream Topics

- `polaris.events.order`
- `polaris.events.payment`

## Consumer Group

- group name: `polaris-workers`
- consumer naming: `{service}-{instance}` (example: `worker-dev-1`)

## Retention Policy

- `MAXLEN ~ 10000` per stream in dev
- goal: keep recent events for debugging while preventing unbounded growth

## Event Envelope (field-based)

- `event_type`: domain event name (example: `order.created`)
- `trace_id`: request or transaction trace id
- `order_id`: optional order id for order-related events
- `payment_id`: optional payment id for payment-related events
- `occurred_at`: RFC3339 UTC timestamp

## Dev Scripts

- bootstrap topics and group:
  - `scripts/queue_bootstrap_dev.ps1`
  - `scripts/queue_bootstrap_dev.sh`
- publish one sample event:
  - `scripts/queue_publish_sample_dev.ps1`
  - `scripts/queue_publish_sample_dev.sh`
- consume one event as worker:
  - `scripts/queue_worker_once_dev.ps1`
  - `scripts/queue_worker_once_dev.sh`
- validate end-to-end publish/consume:
  - `scripts/queue_validate_flow_dev.ps1`
  - `scripts/queue_validate_flow_dev.sh`
