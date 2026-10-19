import {
  to = helm_release.argocd
  id = "argocd/argocd"
}

import {
  to = helm_release.aws_load_balancer_controller
  id = "kube-system/aws-load-balancer-controller"
}
