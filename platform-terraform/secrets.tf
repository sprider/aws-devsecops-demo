resource "aws_secretsmanager_secret" "cognito_client" {
  name = "${local.name_prefix}/cognito-client"
  recovery_window_in_days = 0  # Force immediate deletion for demo/dev environments

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cognito-secret"
  })
}

resource "aws_secretsmanager_secret_version" "cognito_client" {
  secret_id     = aws_secretsmanager_secret.cognito_client.id
  secret_string = jsonencode({
    client_id     = aws_cognito_user_pool_client.demo.id,
    client_secret = aws_cognito_user_pool_client.demo.client_secret
  })
}
