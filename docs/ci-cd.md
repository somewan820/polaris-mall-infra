# CI/CD Gate Baseline (I005)

## Goal

Define a shared CI/CD baseline where deployment is blocked when validation fails.

## Workflow Files

- infra: `.github/workflows/infra-ci-cd.yml`
- api: `.github/workflows/api-ci-cd.yml`
- web: `.github/workflows/web-ci-cd.yml`

## Gate Rules

- `infra`:
  - syntax check must pass
  - migration validation must pass
  - queue publish/consume validation must pass
  - `gate` job fails if any required job fails
- `api`:
  - `go test ./...` must pass
  - build check must pass
  - `gate` job fails if any required job fails
- `web`:
  - router guard test must pass
  - catalog logic test must pass
  - `gate` job fails if any required job fails

## Deploy Trigger

- Deploy job executes only on `push` to `main` and only after `gate` success.
- PR events run validation jobs and gate check, but do not run deploy.

## Branch Protection Recommendation

For each repository:

1. Enable branch protection on `main`.
2. Require status checks before merge.
3. Select the `gate` check from each repo workflow:
   - infra: `gate`
   - api: `gate`
   - web: `gate`
4. Disable force push and deletion for protected branch.
