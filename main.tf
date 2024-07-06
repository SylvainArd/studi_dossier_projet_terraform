provider "aws" {
  region = "us-east-1"
}

# Crée le repository ECR 
resource "aws_ecr_repository" "hello_world" {
  name = "hello-world"
}

# Groupe de sécurité pour le front-end
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Groupe de sécurité pour le back-end
resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Security group for backend instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Rôle IAM pour les instances EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attache la politique ECR à ce rôle
resource "aws_iam_role_policy_attachment" "ec2_role_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# Profil d'instance IAM pour associer le rôle IAM aux instances EC2
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Groupe de sécurité pour l'instance RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow MySQL traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Paire de clés SSH
resource "aws_key_pair" "deployer_key" {
  key_name   = var.key_name
  public_key = file("~/.ssh/${var.key_name}.pub")
}

# Instances EC2 pour le front-end
resource "aws_instance" "frontend_instance" {
  count         = 2
  ami           = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer_key.key_name
  security_groups = [aws_security_group.frontend_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install nginx -y
              sudo systemctl enable nginx
              sudo systemctl start nginx

              # Configure Nginx to serve the React application
              sudo cat > /etc/nginx/conf.d/default.conf <<EOL
              server {
                  listen 80;
                  server_name _;

                  root /usr/share/nginx/html;
                  index index.html;

                  location / {
                      try_files \$uri \$uri/ /index.html;
                  }
              }
              EOL

              sudo systemctl restart nginx
              EOF

  tags = {
    Name = "frontend-instance-${count.index}"
  }
}

# Instances EC2 pour le back-end
resource "aws_instance" "backend" {
  count                  = 2
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups        = [aws_security_group.backend_sg.name]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker
              sudo systemctl start docker
              sudo systemctl enable docker
              EOF

  tags = {
    Name = "backend-instance-${count.index}"
  }
}


output "backend_instance_ips" {
  description = "The public IPs of the backend instances"
  value       = aws_instance.backend[*].public_ip
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.hello_world.repository_url
}

# Load Balancer pour le front-end
resource "aws_elb" "frontend_elb" {
  name               = "frontend-elb"
  availability_zones = ["us-east-1d"] 
  security_groups    = [aws_security_group.frontend_sg.id]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances = aws_instance.frontend_instance[*].id
}

# Instance RDS
resource "aws_db_instance" "default" {
  allocated_storage    = 5
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  identifier           = "mydb-instance"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = "mydb"
  }
}

# AWS Backup Vault
resource "aws_backup_vault" "rds_backup_vault" {
  name = "rds-backup-vault"
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup_role" {
  name = "backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_role_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# AWS Backup Plan
resource "aws_backup_plan" "rds_backup_plan" {
  name = "rds-backup-plan"

  rule {
    rule_name         = "rds-12hour-backup"
    target_vault_name = aws_backup_vault.rds_backup_vault.name
    schedule          = "cron(0 */12 * * ? *)" # Cron expression for every 12 hours

    lifecycle {
      delete_after = 30 # Number of days to retain the backup
    }
  }
}

# AWS Backup Selection
resource "aws_backup_selection" "rds_backup_selection" {
  name          = "rds-backup-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id       = aws_backup_plan.rds_backup_plan.id

  resources = [
    aws_db_instance.default.arn
  ]
}
