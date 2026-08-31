terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.61.0"
    }
  }
  backend "s3" {
    bucket         = "rameez-tfstate-2026-xyz" 
    key            = "terraform.tfstate"       
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"         
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "ecommerce-infra"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

/*# Your existing EC2 Instance (You can move this into a compute module later)
resource "aws_instance" "terraform_ec2-rm" {
  ami           = "ami-0332d564d76dbd8d6"
  instance_type = "t2.micro"
  key_name      = "projectkey-rm"
  
  tags = {
    Name = "terraform_ec2-rm"
  }
}*/

# === ADD THIS BLOCK ===
# This calls the module you created in the /modules/storage/ folder
module "storage_buckets" {
  source = "./modules/storage"

  # Ensure these names are globally unique. 
  # The "logs" value MUST exactly match your backend bucket name above.
  buckets = {
    "images"  = "rameez-product-images-2026-xyz"
    "logs"    = "rameez-tfstate-2026-xyz" 
    "backups" = "rameez-backups-2026-xyz"
  }
}

module "iam_users" {
  source    = "./modules/iam"
  iam_users = ["Ibrahim", "Ron", "Sandip", "Klaudio", "Teyfik"]
}

output "all_iam_users" {
  description = "The names of the 5 provisioned IAM users"
  value       = module.iam_users.user_names
}

module "networking" {
  source = "./modules/networking"
}

# --- Rubric Outputs ---
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "subnet_ids" {
  description = "Public and Private Subnet IDs"
  value = {
    public  = module.networking.public_subnet_ids
    private = module.networking.private_subnet_ids
  }
}
output "security_group_ids" {
  description = "The IDs of the 3-tier Security Groups"
  value = {
    alb = module.networking.alb_sg_id
    app = module.networking.app_sg_id
    db  = module.networking.db_sg_id
  }
}

module "database" {
  source               = "./modules/database"
  private_subnet_ids   = module.networking.private_subnet_ids
  db_security_group_id = module.networking.db_sg_id
}

output "database_endpoint" {
  description = "Database Endpoint"
  value       = module.database.db_endpoint
}

# Store the database password in SSM Parameter Store
resource "aws_ssm_parameter" "db_password" {
  name  = "mysql_psw"
  type  = "SecureString"
  value = "Devops2026!" # This matches your default DB password
}

module "compute" {
  source            = "./modules/compute"
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  app_sg_id         = module.networking.app_sg_id
  alb_sg_id         = module.networking.alb_sg_id
  db_address        = module.database.db_address
}

output "application_url" {
  value = module.compute.application_url
}

output "asg_name" {
  value = module.compute.asg_name
}