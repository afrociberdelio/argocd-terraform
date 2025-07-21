resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Install ArgoCD in your cluster
# data "template_file" "argo_values" {
#   template = file("${path.module}/values.yaml")
# }

resource "helm_release" "argocd" {
  name       = "argocd"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "8.1.3"
  timeout    = 1500
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    file("${path.module}/values.yaml")
  ]
  # values = [
  #   data.template_file.argo_values.rendered
  # ]
}

# Get ArgoCD password
resource "null_resource" "password" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    interpreter = ["powershell", "-Command"]
    command = <<-EOT
      if ($Env:OS -eq "Windows_NT") {
        Write-Output "Executando no Windows"
        for ($i = 0; $i -lt 10; $i++) {
          $b64 = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>$null
          if ($b64) {
            $formatted = $b64 -replace '.{64}', '$&`r`n'
            Set-Content -Path "temp.b64" -Value $formatted -Encoding ascii
            certutil -f -decode temp.b64 argocd-login.txt | Out-Null
            Remove-Item temp.b64
            Write-Output "Senha salva em argocd-login.txt"
            break
          } else {
            Start-Sleep -Seconds 3
          }
        }
      } else {
        Write-Output "Executando no Linux/macOS"
        bash -c "for i in {1..10}; do kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath={.data.password} | base64 -d > argocd-login.txt && exit 0 || sleep 3; done"
      }
    EOT
  }
}

resource "null_resource" "del_argo_pass" {
  depends_on = [null_resource.password]

  provisioner "local-exec" {
    command = "kubectl -n argocd delete secret argocd-initial-admin-secret"
  }
}

# Add repository kubernetes-apps in ArgoCD
resource "kubernetes_secret_v1" "repo_kubernetes_apps" {
  depends_on = [helm_release.argocd]

  metadata {
    name      = "kubernetes-apps"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    url           = "git@github.com:afrociberdelio/kubernetes-apps.git"
    sshPrivateKey = file("${path.module}/kubernetes-apps.pem")
  }
}

# Add repository kubernetes-foundation in ArgoCD
resource "kubernetes_secret_v1" "repo_kubernetes_foundation" {
  depends_on = [helm_release.argocd]

  metadata {
    name      = "kubernetes-foundation"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    url           = "git@github.com:afrociberdelio/kubernetes-foundation.git"
    sshPrivateKey = file("${path.module}/kubernetes-foundation.pem")
  }
}

# Add secrets to ArgoCD dns host
resource "kubernetes_secret_v1" "argocd_tls" {
  metadata {
    name      = "argocd-tls"
    namespace = "argocd"
  }

  type = "tls"

  data = {
    "tls.crt" = filebase64("${path.module}/cert/cert.pem")
    "tls.key" = filebase64("${path.module}/cert/key.pem")
  }
}

# Add apps-in-cluster.yaml to Argocd (Principal app to applications management)
resource "null_resource" "add_repo_secrets" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    interpreter = ["powershell", "-Command"]
    command = <<EOT
      kubectl -n argocd apply -f apps-in-cluster.yaml
    EOT
  }
}

## Create secrets and add repository in ArgoCD
# resource "null_resource" "add_repo_secrets" {
#   depends_on = [helm_release.argocd]

#   provisioner "local-exec" {
#     interpreter = ["powershell", "-Command"]
#     command = <<EOT
#       kubectl -n argocd create secret generic kubernetes-apps-creds --from-file=sshPrivateKey=kubernetes-apps.pem --type=Opaque
#       kubectl -n argocd create secret generic kubernetes-foundation-creds --from-file=sshPrivateKey=kubernetes-foundation.pem --type=Opaque

#       Write-Output "Aguardando CRD 'Repository' ficar disponível..."
#       for ($i = 0; $i -lt 10; $i++) {
#         $ready = kubectl get crd repositories.argoproj.io -o json 2>$null
#         if ($ready) {
#           Write-Output "CRD disponível. Aplicando YAMLs..."
#           kubectl apply -f ./kubernetes-apps.yaml -n argocd
#           kubectl apply -f ./kubernetes-foundation.yaml -n argocd
#           break
#         } else {
#           Write-Output "Aguardando..."
#           Start-Sleep -Seconds 5
#         }
#       }
#     EOT
#   }
# }