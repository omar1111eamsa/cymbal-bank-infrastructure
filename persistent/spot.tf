# Account-level role EC2 needs before it can launch any Spot instance.
# Persistent: it belongs to the account, not to one environment.
resource "aws_iam_service_linked_role" "spot" {
  aws_service_name = "spot.amazonaws.com"
}
