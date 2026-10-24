resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.20.4"
  namespace  = "kube-system"

  values = [yamlencode({
    eni                        = { enabled = true }
    ipam                       = { mode = "eni" }
    egressMasqueradeInterfaces = "en+"
    routingMode                = "native"
    kubeProxyReplacement       = true
    k8sServiceHost             = trimprefix(module.eks_cluster.cluster_endpoint, "https://")
    k8sServicePort             = 443

    prometheus = { enabled = true }
    operator   = { prometheus = { enabled = true } }
    hubble = {
      relay   = { enabled = true }
      ui      = { enabled = true }
      metrics = { enabled = ["dns", "drop", "tcp", "flow", "icmp", "port-distribution"] }
    }
  })]

  depends_on = [module.eks_cluster]
}
