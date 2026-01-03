resource "aws_cognito_user_pool" "demo" {
  name = "${local.name_prefix}-pool"

  auto_verified_attributes = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    developer_only_attribute = false
    mutable                  = true
    string_attribute_constraints {
      min_length = "5"
      max_length = "2048"
    }
  }

  tags = local.tags
}

resource "aws_cognito_user_pool_client" "demo" {
  name            = "${local.name_prefix}-client"
  user_pool_id    = aws_cognito_user_pool.demo.id
  generate_secret = true

  callback_urls = [
    "https://${aws_lb.main.dns_name}/oauth2/idpresponse"
  ]

  logout_urls = [
    "https://${aws_lb.main.dns_name}/logout"
  ]

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "demo" {
  domain       = replace(lower("${local.name_prefix}-auth"), "_", "-")
  user_pool_id = aws_cognito_user_pool.demo.id
}

resource "aws_cognito_user" "seed" {
  count      = var.cognito_user_email == "" ? 0 : 1
  user_pool_id = aws_cognito_user_pool.demo.id
  username     = var.cognito_user_email
  attributes = {
    email          = var.cognito_user_email
    email_verified = "true"
  }
}

locals {
  alb_certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : aws_acm_certificate.alb[0].arn
  alb_self_signed_expiration = var.acm_certificate_arn == "" ? tls_self_signed_cert.alb[0].validity_end_time : ""
}

resource "aws_lb" "main" {
  name               = substr("${local.name_prefix}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = values(aws_subnet.public)[*].id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb"
  })
}

resource "tls_private_key" "alb" {
  count     = var.acm_certificate_arn == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  count                = var.acm_certificate_arn == "" ? 1 : 0
  private_key_pem      = tls_private_key.alb[0].private_key_pem
  validity_period_hours = 8760
  early_renewal_hours  = 720
  dns_names            = [aws_lb.main.dns_name]
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]

  subject {
    common_name  = aws_lb.main.dns_name
    organization = var.project
  }
}

resource "aws_acm_certificate" "alb" {
  count             = var.acm_certificate_arn == "" ? 1 : 0
  private_key       = tls_private_key.alb[0].private_key_pem
  certificate_body  = tls_self_signed_cert.alb[0].cert_pem
  certificate_chain = tls_self_signed_cert.alb[0].cert_pem

  tags = local.tags
}

resource "aws_lb_target_group" "app" {
  name        = substr("${local.name_prefix}-tg", 0, 32)
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
    path                = "/healthz"
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol   = "HTTPS"
      port       = "443"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.alb_certificate_arn

  default_action {
    type  = "authenticate-cognito"
    order = 1

    authenticate_cognito {
      user_pool_arn             = aws_cognito_user_pool.demo.arn
      user_pool_client_id       = aws_cognito_user_pool_client.demo.id
      user_pool_domain          = aws_cognito_user_pool_domain.demo.domain
      on_unauthenticated_request = "authenticate"
    }
  }

  default_action {
    type             = "forward"
    order            = 2
    target_group_arn = aws_lb_target_group.app.arn
  }
}
