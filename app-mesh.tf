terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.1.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

resource "aws_vpc" "terraform" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_appmesh_mesh" "terraform" {
  name = "terraform"
}

resource "aws_service_discovery_private_dns_namespace" "terraform" {
  name = "terraform"
  vpc  = aws_vpc.terraform.id
}

resource "aws_service_discovery_service" "frontend-v1" {
  name = "frontend-v1"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.terraform.id

    dns_records {
      ttl  = 0
      type = "A"
    }
  }
}

resource "aws_service_discovery_service" "frontend-v2" {
  name = "frontend-v2"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.terraform.id

    dns_records {
      ttl  = 0
      type = "A"
    }
  }
}

resource "aws_appmesh_virtual_router" "frontend" {
  name      = "frontend-router"
  mesh_name = aws_appmesh_mesh.terraform.id

  spec {
    listener {
      port_mapping {
        port     = 8080
        protocol = "http"
      }
    }
  }
}

resource "aws_appmesh_route" "frontend" {
  name                = "frontend"
  mesh_name           = aws_appmesh_mesh.terraform.id
  virtual_router_name = aws_appmesh_virtual_router.frontend.name

  spec {
    http_route {
      match {
        prefix = "/"
      }

      action {
        weighted_target {
          virtual_node = aws_appmesh_virtual_node.frontend-v1.name
          weight       = 90
        }

        weighted_target {
          virtual_node = aws_appmesh_virtual_node.frontend-v2.name
          weight       = 10
        }
      }
    }
  }
}

resource "aws_appmesh_virtual_service" "frontend-v1" {
  name      = "frontend-v1.terraform.local"
  mesh_name = aws_appmesh_mesh.terraform.id

  spec {
    provider {
      virtual_node {
        virtual_node_name = aws_appmesh_virtual_node.frontend-v1.name
      }
    }
  }
}

resource "aws_appmesh_virtual_service" "frontend-v2" {
  name      = "frontend-v2.terraform.local"
  mesh_name = aws_appmesh_mesh.terraform.id

  spec {
    provider {
      virtual_node {
        virtual_node_name = aws_appmesh_virtual_node.frontend-v2.name
      }
    }
  }
}

resource "aws_appmesh_virtual_node" "frontend-v1" {
  name      = "frontend-v1"
  mesh_name = aws_appmesh_mesh.terraform.id

  spec {
    backend {
      virtual_service {
        virtual_service_name = "frontend-v1.terraform.local"
      }
    }

    listener {
      port_mapping {
        port     = 8080
        protocol = "http"
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = "frontend-v1"
        namespace_name = aws_service_discovery_private_dns_namespace.terraform.name
      }
    }
  }
}

resource "aws_appmesh_virtual_node" "frontend-v2" {
  name      = "frontend-v2"
  mesh_name = aws_appmesh_mesh.terraform.id

  spec {
    backend {
      virtual_service {
        virtual_service_name = "frontend-v2.terraform.local"
      }
    }

    listener {
      port_mapping {
        port     = 8080
        protocol = "http"
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = "frontend-v2"
        namespace_name = aws_service_discovery_private_dns_namespace.terraform.name
      }
    }
  }
}