<<<<<<< HEAD
# Fixes + CI/CD for the fraud-detector MLOps project

## Bugs fixed

| File | Bug | Fix |
|---|---|---|
| `k8s/06-fastapi-deployment.yaml` | Service `ports:` list was malformed (name on one item, port/targetPort on a separate item) - `kubectl apply` rejects it | Merged into one port entry |
| `k8s/01-serviceaccounts.yaml` | `fastapi-sa` shared `mlflow-sa`'s role, which grants Get/Put/List/Delete on the S3 bucket | New `fraud-api-s3-readonly` role, Get/List only - see `iam/` |
| `k8s/02-secrets.yaml` | Real RDS password committed in plaintext | Replaced with placeholders; real secret is created by the CI deploy step from GitHub Secrets |
| `k8s/train-job.yaml` | Fixed Job name - a second `apply` fails because Jobs are immutable; no resource limits | Templated `__RUN_ID__`/`__IMAGE_TAG__`, added requests/limits and `backoffLimit` |
| `app/requirements.txt` | `boto3`, `scikit-learn`, `numpy` each listed once unpinned, `scikit-learn` listed again pinned | Deduped, everything pinned once |
| `app/train.py` | Always promoted the latest run to Production regardless of score | Added an F1 threshold gate (`MIN_F1_THRESHOLD`, default 0.85) - `sys.exit(1)` if it doesn't clear the bar |

**Not fixed here, worth doing next:** no TLS on `08-ingress.yaml` (HTTP only), `resources-setup` doc references namespace `ml-prod` in its verify steps while every manifest uses `mlops` - pick one.

## Two workflows, not one

- **`app-cicd.yml`** - push to `main` (path-filtered to app/deploy files): test → build + Trivy scan → push to ECR → `kubectl set image` → smoke test against `/health`.
- **`train-promote.yml`** - manual or weekly cron, not on every push: build the train image → run it as a k8s Job → **the eval gate and promotion both happen inside `train.py`, in-cluster** - if F1 misses the threshold the script exits 1, the Job's condition goes to `Failed`, and `kubectl wait` fails the workflow before it ever restarts serving. Only on success does `restart-serving` run `kubectl rollout restart` so the FastAPI pod actually reloads the newly-promoted model.

## One-time setup before these run

All of the below is now automated by **`terraform/`** — see
`terraform/README.md` for the important caveat about your account already
having resources with these same names, then run `terraform apply` and
copy the outputs into GitHub secrets. What it replaces:

1. ~~GitHub OIDC → AWS role~~ — `terraform/iam-github-oidc.tf` creates this; the output `github_actions_ci_role_arn` is your `AWS_CI_ROLE_ARN` secret.
2. **Repo secrets**: `AWS_ACCOUNT_ID`, `AWS_REGION`, `AWS_CI_ROLE_ARN`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME`, `DB_HOST` — mapping from terraform outputs is in `terraform/README.md`.
3. ~~Apply the IAM changes by hand~~ — `terraform/iam-irsa.tf` creates `mlflow-s3-access` and `fraud-api-s3-readonly` with the exact role names the k8s manifests already reference, so no manifest changes needed once applied.
4. `k8s/01-serviceaccounts.yaml` and `k8s/06-fastapi-deployment.yaml` just work once the Terraform apply finishes — the ARNs they reference will resolve.
5. Add a `tests/` directory and uncomment the `pytest` line in `app-cicd.yml` — there's currently no test suite in the repo. (Still on you — Terraform provisions infra, not test coverage.)
=======
# mlops-fraud-detection
>>>>>>> b826fdbb04d1ebe7ccfac54e2836f4282e02eae7
