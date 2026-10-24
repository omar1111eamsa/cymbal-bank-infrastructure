resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.5"
  namespace        = "argocd"
  create_namespace = true



  depends_on = [aws_eks_addon.coredns]
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

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.7"
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      master-app = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = "https://github.com/omar1111eamsa/cymbal-bank-infrastructure.git"
          targetRevision = "main"
          path           = "gitops/apps"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}


