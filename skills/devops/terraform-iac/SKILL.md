---
name: terraform-iac
description: Terraform Infrastructure as Code best practices for AWS, including project structure, module patterns, state management, variable design, and CI/CD integration with GitHub Actions.
---

# Terraform IaC Best Practices

## Project Structure

```
infrastructure/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars      # dev-specific values (not committed if sensitive)
│   │   └── backend.tf
│   ├── staging/
│   └── production/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecs-service/
│   ├── rds/
│   └── alb/
└── .github/workflows/terraform.yml
```

## Backend Configuration (Remote State)

```hcl
# environments/production/backend.tf
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"  # Prevents concurrent apply
  }
}
```

## Module Pattern

```hcl
# modules/ecs-service/variables.tf
variable "service_name" {
  description = "ECS service name"
  type        = string
}

variable "image_uri" {
  description = "Docker image URI"
  type        = string
}

variable "cpu" {
  description = "Task CPU units"
  type        = number
  default     = 256
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "CPU must be a valid Fargate value."
  }
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
  sensitive   = false
}

variable "secrets" {
  description = "Secrets from SSM Parameter Store"
  type        = map(string)  # name → SSM path
  default     = {}
  sensitive   = true
}
```

```hcl
# modules/ecs-service/main.tf
resource "aws_ecs_task_definition" "this" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name  = var.service_name
    image = var.image_uri

    environment = [
      for k, v in var.environment_variables : { name = k, value = v }
    ]

    secrets = [
      for name, valueFrom in var.secrets : { name = name, valueFrom = valueFrom }
    ]

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.service_name}"
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/actuator/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}
```

```hcl
# modules/ecs-service/outputs.tf
output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "Latest task definition ARN"
  value       = aws_ecs_task_definition.this.arn
}
```

## Environment-Specific Usage

```hcl
# environments/production/main.tf
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Project     = "myapp"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"
  name   = "myapp-prod"
  cidr   = "10.0.0.0/16"
}

module "api_service" {
  source       = "../../modules/ecs-service"
  service_name = "myapp-api"
  image_uri    = "${var.ecr_registry}/myapp:${var.image_tag}"
  cpu          = 512
  memory       = 1024

  environment_variables = {
    SPRING_PROFILES_ACTIVE = "production"
    CORS_ALLOWED_ORIGINS   = "https://app.example.com"
  }

  secrets = {
    DB_PASSWORD = aws_ssm_parameter.db_password.name
    JWT_SECRET  = aws_ssm_parameter.jwt_secret.name
  }
}
```

## Secrets via SSM Parameter Store

```hcl
# Never store secrets in tfvars — use SSM
resource "aws_ssm_parameter" "db_password" {
  name        = "/myapp/production/db-password"
  type        = "SecureString"
  value       = var.db_password    # Passed via CI secret, not committed
  description = "Production DB password"
  tags        = { Environment = "production" }
}

# Reference in task definition
data "aws_ssm_parameter" "db_password" {
  name = "/myapp/production/db-password"
}
```

## GitHub Actions — Terraform CI/CD

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  pull_request:
    paths: ['infrastructure/**']
  push:
    branches: [main]
    paths: ['infrastructure/**']

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infrastructure/environments/production
    permissions:
      id-token: write
      contents: read
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_TERRAFORM_ROLE }}
          aws-region: ap-northeast-2

      - uses: hashicorp/setup-terraform@v3

      - run: terraform init

      - run: terraform validate

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        continue-on-error: true

      - name: Comment PR with plan
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `\`\`\`\n${{ steps.plan.outputs.stdout }}\n\`\`\``
            })

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
```

## Best Practices

- **State**: Always use remote state (S3 + DynamoDB lock); never commit `.tfstate`
- **Secrets**: Use SSM Parameter Store or Vault — never `.tfvars` for passwords
- **Modules**: One module per logical resource group; version pin with `version = "~> X.Y"`
- **Tags**: Use `default_tags` in provider for consistent resource tagging
- **Validation**: Add `validation` blocks to catch invalid inputs early
- **Formatting**: Always run `terraform fmt` before committing
- **Plan reviews**: Require PR plan comments before applying to production
- **Workspaces**: Prefer separate state files per environment over workspaces
