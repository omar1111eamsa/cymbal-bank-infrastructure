import {
  to = helm_release.argocd
  id = "argocd/argocd"
}

removed {
  from = helm_release.aws_load_balancer_controller

  lifecycle {
    destroy = false
  }
}
