# Cymbal Bank Infrastructure

Zero-trust, cloud-native banking microservices platform deployed on AWS EKS using Terraform, HCP Terraform, Cilium (eBPF), and Istio Ambient Mesh.

## Layout

| Path | What | Applied by |
|---|---|---|
| `terraform/bootstrap/` | OIDC trust (HCP, GitHub), HCP workspaces, CI roles, `main` ruleset | locally, by hand (local state) |
| `terraform/persistent/` | DNS zone, TLS certificate, secrets, KMS keys: survives destroys | HCP workspace `cymbal-bank-persistent` |
| `terraform/ephemeral/` | VPC, EKS, Cilium, Karpenter, ArgoCD: destroyed and rebuilt | HCP workspace `cymbal-bank-prod` |
| `gitops/` | everything inside the cluster, synced by ArgoCD | ArgoCD |
| `.github/workflows/` | checks on every PR, build on merge, destroy on demand | GitHub Actions |
