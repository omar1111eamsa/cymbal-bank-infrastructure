resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.20.4"
  namespace  = "kube-system"

  # Installed before any node exists: its pods start once nodes join (nodes.tf)
  wait = false

  values = [yamlencode({
    eni                        = { enabled = true }
    cni                        = { exclusive = false }
    socketLB                   = { hostNamespaceOnly = true }
    ipam                       = { mode = "eni" }
    egressMasqueradeInterfaces = "en+"
    routingMode                = "native"
    # Istio Ambient SNATs kubelet probes to 169.254.7.127 with iptables; BPF host routing
    # skips iptables, so probe replies are lost. Legacy routing keeps them working.
    bpf                  = { hostLegacyRouting = true }
    kubeProxyReplacement = true
    k8sServiceHost       = trimprefix(module.eks_cluster.cluster_endpoint, "https://")
    k8sServicePort       = 443
    rollOutCiliumPods    = true
    operator             = { prometheus = { enabled = true }, rollOutPods = true }

    prometheus = { enabled = true }
    hubble = {
      relay   = { enabled = true }
      ui      = { enabled = true }
      metrics = { enabled = ["dns", "drop", "tcp", "flow", "icmp", "port-distribution"] }
    }
  })]

  depends_on = [module.eks_cluster]
}
