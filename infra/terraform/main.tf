locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

module "network" {
  source = "./modules/network"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  enable_nat_gateway    = var.enable_nat_gateway
  tags                  = local.common_tags
}

data "aws_iam_roles" "cluster_role" {
  name_regex = ".*LabEksClusterRole.*"
}

data "aws_iam_roles" "node_role" {
  name_regex = ".*LabEksNodeRole.*"
}

module "eks" {
  source = "./modules/eks"

  project_name         = var.project_name
  environment          = var.environment
  cluster_name         = var.eks_cluster_name
  cluster_version      = var.eks_cluster_version
  cluster_role_arn     = var.eks_cluster_role_arn != "" ? var.eks_cluster_role_arn : tolist(data.aws_iam_roles.cluster_role.arns)[0]
  node_role_arn        = var.eks_node_role_arn != "" ? var.eks_node_role_arn : tolist(data.aws_iam_roles.node_role.arns)[0]
  subnet_ids           = module.network.private_subnet_ids
  instance_types       = var.node_instance_types
  ami_type             = var.node_ami_type
  desired_size         = var.node_desired_size
  min_size             = var.node_min_size
  max_size             = var.node_max_size
  tags                 = local.common_tags
}

module "data" {
  source = "./modules/data"

  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.network.vpc_id
  vpc_cidr                 = var.vpc_cidr
  private_subnet_ids       = module.network.private_subnet_ids
  rds_instance_class       = var.rds_instance_class
  rds_allocated_storage    = var.rds_allocated_storage
  rds_master_username      = var.rds_master_username
  rds_master_password      = var.rds_master_password
  redis_node_type          = var.redis_node_type
  redis_num_cache_nodes    = var.redis_num_cache_nodes
  dynamodb_table_name      = var.dynamodb_table_name
  analytics_sqs_queue_name = var.analytics_sqs_queue_name
  tags                     = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  repositories = var.ecr_repositories
  tags         = local.common_tags
}
