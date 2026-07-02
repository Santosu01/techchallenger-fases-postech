variable "project_name" {
  type        = string
  description = "Nome base para tags e recursos."
  default     = "togglemaster"
}

variable "environment" {
  type        = string
  description = "Ambiente alvo (ex: homolog, prod)."
  default     = "homolog"
}

variable "aws_region" {
  type        = string
  description = "Regiao AWS."
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Perfil AWS local (vazio para padrao)."
  default     = ""
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR principal da VPC."
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs usadas na VPC."
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs das subnets publicas."
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs das subnets privadas."
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Cria NAT Gateway para saida das subnets privadas."
  default     = true
}

variable "eks_cluster_name" {
  type        = string
  description = "Nome do cluster EKS."
  default     = "togglemaster-eks"
}

variable "eks_cluster_version" {
  type        = string
  description = "Versao Kubernetes do EKS."
  default     = "1.30"
}

variable "eks_cluster_role_arn" {
  type        = string
  description = "ARN da role do cluster EKS (LabRole no Academy)."
  default     = ""
}

variable "eks_node_role_arn" {
  type        = string
  description = "ARN da role do node group EKS (LabRole no Academy)."
  default     = ""
}

variable "node_instance_types" {
  type        = list(string)
  description = "Tipos de instancia para node group."
  default     = ["t3.small"]
}

variable "node_ami_type" {
  type        = string
  description = "AMI type do EKS node group."
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_desired_size" {
  type        = number
  default     = 2
}

variable "node_min_size" {
  type        = number
  default     = 1
}

variable "node_max_size" {
  type        = number
  default     = 4
}

variable "rds_instance_class" {
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type        = number
  default     = 20
}

variable "rds_master_username" {
  type        = string
  description = "Usuario master dos bancos RDS."
}

variable "rds_master_password" {
  type        = string
  description = "Senha master dos bancos RDS."
  sensitive   = true
}

variable "redis_node_type" {
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  type        = number
  default     = 1
}

variable "dynamodb_table_name" {
  type        = string
  default     = "ToggleMasterAnalytics"
}

variable "analytics_sqs_queue_name" {
  type        = string
  default     = "togglemaster-analytics-queue"
}

variable "ecr_repositories" {
  type        = list(string)
  default     = ["auth-service", "flag-service", "targeting-service", "evaluation-service", "analytics-service"]
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags adicionais."
}
