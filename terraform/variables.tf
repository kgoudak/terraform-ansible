# Region to create infrastructure
variable "region" {
  type        = string
  default     = "us-east-1"
  description = "The region to create the infrastructure"
}

# Declare the data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC CIDR block
variable "vpc_cidr" {
  default     = "10.10.0.0/20"
  description = "The CIDR block to be used by the VPC"
}

# The number of bits to extend VPC's CIDR as per https://www.terraform.io/docs/configuration/functions/cidrsubnet.html
variable "subnet_cidr_newbits" {
  type        = string
  default     = 4
  description = "The newbits value as per cidrsubnet function docs"
}

# Private key to be used when SSHing to EC2 instances
variable "private_key_name" {
  type        = string
  description = "The private key to be used in order to SSH to EC2 instances"
}

# The path to the key pair file
variable "private_key_file_path" {
  type        = string
  description = "The location of the key-pair pem file"
}

# The location from which a user can SSH to bastion hosts
variable "ssh_location" {
  type        = string
  description = "The IP address range that can be used to SSH to the Bastion hosts"
}

# The EC2 instance type
variable "ec2_instance_type" {
  type        = string
  default     = "t2.micro"
  description = "The EC2 instance type"
}

# Map of Linux2 AMI ID / region
variable "ec2_image_ids" {
  type        = map
  description = "The id of the machine image (AMI) to use for the server."

  default = {
    us-east-1      = "ami-0fc61db8544a617ed"
    us-east-2      = "ami-0e01ce4ee18447327"
    us-west-1      = "ami-09a7fe78668f1e2c0"
    us-west-2      = "ami-0ce21b51cb31a48b8"
    ap-south-1     = "ami-03b5297d565ef30a6"
    ap-northeast-2 = "ami-0db78afd3d150fc18"
    ap-southeast-1 = "ami-0cbc6aae997c6538a"
    ap-southeast-2 = "ami-08fdde86b93accf1c"
    ap-northeast-1 = "ami-052652af12b58691f"
    ca-central-1   = "ami-0bf54ac1b628cf143"
    eu-central-1   = "ami-0ec1ba09723e5bfac"
    eu-west-1      = "ami-04d5cc9b88f9d1d39"
    eu-west-2      = "ami-0cb790308f7591fa6"
    eu-west-3      = "ami-07eda9385feb1e969"
    eu-north-1     = "ami-0f630db6194a81ad0"
    sa-east-1      = "ami-0b032e878a66c3b68"
  }
}
