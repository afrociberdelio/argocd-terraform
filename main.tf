resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

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
}

# Get ArgoCD password
# resource "null_resource" "password" {
#   depends_on = [helm_release.argocd]

# provisioner "local-exec" {
#   interpreter = ["/bin/bash", "-c"]
#   command = "if [[ \"$(uname -s)\" != \"Windows_NT\" ]]; then echo \"Executando no Linux/macOS\"; for i in {1..10}; do PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null); if [[ -n \"$PASSWORD\" ]]; then echo \"$PASSWORD\" | base64 -d > argocd-login.txt; echo \"Senha salva em argocd-login.txt\"; exit 0; else sleep 3; fi; done; else echo \"Executando no Windows\"; powershell -Command \"...\"; fi"
#   }
# }

resource "null_resource" "password" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      if [[ "$(uname -s)" != "Windows_NT" ]]; then
        echo "Executando no Linux/macOS"
        for i in {1..10}; do
          PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null)
          if [[ -n "$PASSWORD" ]]; then
            echo "$PASSWORD" | base64 -d > argocd-login.txt
            echo "Senha salva em argocd-login.txt"
            exit 0
          else
            sleep 3
          fi
        done
      else
        echo "Executando no Windows"
        powershell -Command "
          Write-Output 'Executando no Windows'
          for (\$i = 0; \$i -lt 10; \$i++) {
            \$b64 = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>\$null
            if (\$b64) {
              \$formatted = \$b64 -replace '.{64}', '\$&`r`n'
              Set-Content -Path 'temp.b64' -Value \$formatted -Encoding ascii
              certutil -f -decode temp.b64 argocd-login.txt | Out-Null
              Remove-Item temp.b64
              Write-Output 'Senha salva em argocd-login.txt'
              break
            } else {
              Start-Sleep -Seconds 3
            }
          }
        "
      fi
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
    # interpreter = ["powershell", "-Command"]
    command = "kubectl -n argocd apply -f apps-in-cluster.yaml"
  }
}
