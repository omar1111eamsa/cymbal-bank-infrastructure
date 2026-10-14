resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.4.4"
  namespace        = "argocd"
  create_namespace = true



  depends_on = [module.eks_cluster]
}
