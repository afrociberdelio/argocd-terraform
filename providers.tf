terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.37.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.2"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "k3d-laboratorio" # Set kubernetes context here
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
    config_context = "k3d-laboratorio" 
  }
}
