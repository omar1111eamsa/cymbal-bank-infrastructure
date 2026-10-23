resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.5"
  namespace        = "argocd"
  create_namespace = true



  depends_on = [module.eks_cluster]
  values = [yamlencode({
    controller = {
      metrics = { enabled = true, serviceMonitor = { enabled = true } }
    }
    server = {
      metrics = { enabled = true, serviceMonitor = { enabled = true } }
    }
    repoServer = {
      metrics = { enabled = true, serviceMonitor = { enabled = true } }
    }
    applicationSet = {
      metrics = { enabled = true, serviceMonitor = { enabled = true } }
    }
  })]
}


