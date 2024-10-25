data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name = "${var.prefix}-vpc"
  cidr = local.vpc_cidr_block

  azs              = data.aws_availability_zones.available.names
  private_subnets  = local.private_subnet_cidrs
  public_subnets   = local.public_subnet_cidrs
  database_subnets = local.database_subnet_cidrs

  private_subnet_names  = local.private_subnet_names
  public_subnet_names   = local.public_subnet_names
  database_subnet_names = local.database_subnet_names

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = local.tags
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.1.1"

  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = local.tags
}

module "alb_frontend" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.11.2"

  name = "${var.prefix}-frontend-alb"

  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  enable_deletion_protection = false

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = {
    http_https_redirect = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    https = {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
      certificate_arn = module.acm.acm_certificate_arn

      forward = {
        target_group_key = "frontend"
      }
    }
  }

  target_groups = {
    frontend = {
      backend_protocol = "HTTP"
      backend_port     = 3000
      target_type      = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      create_attachment = false
    }
  }

  tags = local.tags
}

module "alb_backend" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.11.2"

  name = "${var.prefix}-backend-alb"

  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets

  enable_deletion_protection = false

  security_group_ingress_rules = {
    all_http = {
      from_port                    = 80
      to_port                      = 80
      ip_protocol                  = "tcp"
      description                  = "HTTP web traffic"
      referenced_security_group_id = module.frontend_container_sg.security_group_id
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "backend"
      }
    }
  }

  target_groups = {
    backend = {
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      create_attachment = false
    }
  }

  tags = local.tags
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.11.4"

  cluster_name = "${var.prefix}-cluster"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
        base   = 20
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  services = {
    "${var.prefix}-frontend" = {
      cpu    = 1024
      memory = 4096
      container_definitions = {

        "${var.prefix}-fluent" = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "public.ecr.aws/aws-containers/${var.prefix}-fluent:latest"
          firelens_configuration = {
            type = "fluentbit"
          }
          memory_reservation = 50
        }

        "${var.prefix}-frontend" = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "public.ecr.aws/aws-containers/${var.prefix}-frontend:latest"

          health_check = {
            command = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
          }

          port_mappings = [
            {
              name          = "${var.prefix}-frontend"
              containerPort = 3000
              hostPort      = 3000
              protocol      = "tcp"
            }
          ]

          readonly_root_filesystem = false

          depends_on = [{
            containerName = "${var.prefix}-fluent"
            condition     = "START"
          }]

          enable_cloudwatch_logging = false
          log_configuration = {
            logDriver = "awsfirelens"
            options = {
              Name                    = "firehose"
              region                  = var.region
              delivery_stream         = "my-stream"
              log-driver-buffer-limit = "2097152"
            }
          }
          memory_reservation = 100
        }
      }

      subnet_ids = module.vpc.private_subnets
      security_group_rules = {
        alb_ingress = {
          type                     = "ingress"
          from_port                = 3000
          to_port                  = 3000
          protocol                 = "tcp"
          description              = "Service port"
          source_security_group_id = module.alb_frontend.security_group_id
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }

    "${var.prefix}-backend" = {
      cpu    = 1024
      memory = 4096
      container_definitions = {
        "${var.prefix}-backend" = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "public.ecr.aws/aws-containers/${var.prefix}-backend:latest"
          port_mappings = [
            {
              name          = "${var.prefix}-backend"
              containerPort = 8080
              hostPort      = 8080
              protocol      = "tcp"
            }
          ]
        }
      }

      subnet_ids = module.vpc.private_subnets
      security_group_rules = {
        alb_ingress = {
          type                     = "ingress"
          from_port                = 8080
          to_port                  = 8080
          protocol                 = "tcp"
          description              = "Service port"
          source_security_group_id = module.alb_backend.security_group_id
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }

  tags = local.tags
}

module "frontend_container_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = "${var.prefix}-frontend-container-sg"
  description = "Security group for the frontend container"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 3000
      to_port                  = 3000
      protocol                 = "tcp"
      description              = "Allow traffic from ALB"
      source_security_group_id = module.alb_frontend.security_group_id
    }
  ]
  egress_rules = ["all-all"]

  tags = local.tags
}

module "backend_container_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = "${var.prefix}-backend-container-sg"
  description = "Security group for the backend container"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      description              = "Allow traffic from ALB"
      source_security_group_id = module.alb_backend.security_group_id
    }
  ]
  egress_rules = ["all-all"]

  tags = local.tags
}

module "rds" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "5.1.0"

  name           = "${var.prefix}-aurora"
  engine         = "aurora-mysql"
  engine_version = "5.7.mysql_aurora.2.07.1"
  instance_type  = "db.t3.small"
  vpc_id         = module.vpc.vpc_id
  subnets        = module.vpc.database_subnets

  apply_immediately            = true
  backup_retention_period      = 5
  preferred_backup_window      = "07:00-09:00"
  preferred_maintenance_window = "Mon:00:00-Mon:03:00"

  db_subnet_group_name    = "${var.prefix}-aurora-subnet-group"
  db_parameter_group_name = "${var.prefix}-aurora-parameter-group"

  create_security_group  = false
  vpc_security_group_ids = [module.backend_container_sg.security_group_id]

  tags = local.tags
}

resource "aws_lb_target_group" "frontend_target_group" {
  name     = "${var.prefix}-frontend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "backend_target_group" {
  name     = "${var.prefix}-backend-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# AWS AppSync Configuration
module "appsync" {
  source  = "terraform-aws-modules/appsync/aws"
  version = "2.5.1"

  name = "${var.prefix}-graphql-api"

  schema = file("${path.module}/schema.graphql")

  visibility = "GLOBAL"

  domain_name_association_enabled = false
  caching_enabled                 = false

  introspection_config = "ENABLED"
  query_depth_limit    = 10
  resolver_count_limit = 25

  api_keys = {
    default = null
  }

  authentication_type = "API_KEY"

  additional_authentication_provider = {
    iam = {
      authentication_type = "AWS_IAM"
    }
  }

  datasources = {
    rds = {
      type          = "RELATIONAL_DATABASE"
      cluster_arn   = module.rds.rds_cluster_arn
      secret_arn    = aws_secretsmanager_secret.rds_secret.arn
      database_name = "coolsewingstuff"
      schema        = "public"
    }
  }

  resolvers = {
    "Query.getPatterns" = {
      data_source       = "rds"
      type              = "Query"
      field             = "getPatterns"
      request_template  = file("${path.module}/request-mapping-template.vtl")
      response_template = file("${path.module}/response-mapping-template.vtl")
    }
  }

  tags = local.tags
}

resource "aws_secretsmanager_secret" "rds_secret" {
  name = "${var.prefix}-rds-secret"

  tags = local.tags
}

resource "aws_iam_role" "rds_access_role" {
  name = "${var.prefix}-rds-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "rds_access_policy" {
  name = "${var.prefix}-rds-access-policy"
  role = aws_iam_role.rds_access_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds-db:connect"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${module.rds.rds_cluster_id}/dbuser"
      }
    ]
  })
}

resource "aws_iam_role" "appsync_service_role" {
  name = "${var.prefix}-appsync-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "appsync_service_role_policy" {
  name = "${var.prefix}-appsync-service-role-policy"
  role = aws_iam_role.appsync_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Effect   = "Allow"
        Resource = module.rds.rds_cluster_arn
      },
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.rds_secret.arn
      }
    ]
  })
}
