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

网关路由：

- `/api/*` -> `http://host.docker.internal:9000`
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
