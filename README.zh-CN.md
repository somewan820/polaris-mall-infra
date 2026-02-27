# Polaris Mall Infra

语言：中文 | [English](README.md)

`polaris-mall-infra` 提供 Polaris Mall 在本地与共享环境的基础设施基线。

## 当前已实现

- I001 基线：
  - 环境变量模板：
    - `env/.env.dev.example`
    - `env/.env.stage.example`
    - `env/.env.prod.example`
  - 本地拓扑：
    - `docker-compose.dev.yml`
    - `gateway/nginx.dev.conf`
  - 引导脚本：
    - `scripts/bootstrap_dev.ps1`
    - `scripts/bootstrap_dev.sh`
  - 拓扑文档：
    - `docs/topology.md`
- I002 基线：
  - 版本化迁移流水线：
    - `scripts/migrate_dev.ps1`
    - `scripts/migrate_dev.sh`
  - 最近一次迁移回滚能力
  - 迁移验证脚本：
    - `scripts/migrate_validate_dev.ps1`
    - `scripts/migrate_validate_dev.sh`
  - 数据库结构文件：
    - `migrations/0001_initial.sql`
    - `migrations/0002_fulfillment_audit.sql`
    - `migrations/rollback/0001_initial.down.sql`
    - `migrations/rollback/0002_fulfillment_audit.down.sql`
- I003 基线：
  - 网关按 `admin`、`业务 API`、`支付回调`分流
  - `/api/v1/*` 与 `/api/v1/admin/*` 转发 Authorization
  - 支付回调入口：`POST /api/v1/payments/callback/mockpay`
  - Web/API/回调流量按路由设置超时策略
- I004 基线：
  - 基于 Redis Stream 的订单/支付事件主题
  - Dev 环境 worker 消费组运行脚本
  - 发布并消费至少一条事件的验证脚本
- I005 基线：
  - Infra 仓库 GitHub Actions CI/CD gate 工作流
  - gate 任务阻断失败校验，防止部署继续
  - 仅 `main` 分支 push 触发部署任务
  - 三仓分支保护与必过检查清单文档
- I006 基线：
  - 网关统一 JSON 日志格式，包含 request/trace/correlation ID
  - Dev 组合新增 Prometheus + Grafana + Loki + exporters
  - 预置仪表盘 `Polaris Infra Overview`
  - 关键告警规则 `CriticalCheckoutProbeFailed`
  - 可观测验证脚本：
    - `scripts/observability_validate_dev.ps1`
    - `scripts/observability_validate_dev.sh`

## 本地初始化

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\bootstrap_dev.ps1"
```

生成 `.env` 后启动基础服务：

```powershell
docker compose -f .\docker-compose.dev.yml --env-file .\.env up -d
```

## Dev 服务端口

- Postgres: `127.0.0.1:5432`
- Redis: `127.0.0.1:6379`
- Gateway: `127.0.0.1:8080`
- Prometheus: `127.0.0.1:9090`
- Alertmanager: `127.0.0.1:9093`
- Grafana: `127.0.0.1:3000`
- Loki: `127.0.0.1:3100`
- Nginx Exporter: `127.0.0.1:9113`
- Blackbox Exporter: `127.0.0.1:9115`

网关路由：

- `/api/v1/admin/*` -> `http://host.docker.internal:9000`（转发 Authorization，`15s` 超时）
- `/api/v1/payments/callback/mockpay` -> `http://host.docker.internal:9000`（仅 `POST`，`20s` 超时）
- `/api/v1/*` -> `http://host.docker.internal:9000`（`10s` 超时）
- `/api/*` -> `http://host.docker.internal:9000`（兜底）
- `/` -> `http://host.docker.internal:5173`

## 迁移与回滚（I002）

执行所有待应用迁移：

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\migrate_dev.ps1"
```

回滚最近一次已应用迁移：

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\migrate_dev.ps1" -Rollback
```

验证迁移与回滚链路：

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\migrate_validate_dev.ps1"
```

## 异步事件基线（I004）

主题：

- `polaris.events.order`
- `polaris.events.payment`

消费组：

- `polaris-workers`

初始化主题与消费组：

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\queue_bootstrap_dev.ps1"
```

发布示例事件：

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\queue_publish_sample_dev.ps1" -Topic order
```

执行一次 worker 消费：

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\queue_worker_once_dev.ps1" -Topic order
```

验证发布与消费链路：

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\queue_validate_flow_dev.ps1"
```

## CI/CD 基线（I005）

- 工作流文件：`.github/workflows/infra-ci-cd.yml`
- 规则与分支保护清单：`docs/ci-cd.md`

## 可观测基线（I006）

- 文档：`docs/observability.md`
- 仪表盘文件：`observability/grafana/dashboards/polaris-infra-overview.json`
- 告警规则：`observability/prometheus/alert.rules.yml`

验证可观测栈：

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\observability_validate_dev.ps1"
```
