### Clone this repo
```
git clone https://github.com/afrociberdelio/argocd-terraform.git
```
### Execute the terraform script to create resources in your cluster
```
terraform init
```
```
terraform plan
```
```
terraform apply -auto-approve
```

### Após o primeiro deploy, você precisa alterar o arquivo values.yaml
#### Altere o valor da chave server.ingress.enabled: true, como exemplo abaixo:
```yaml
server:
  ingress:
    enabled: true # <-- Altere esse campo para true
    controller: generic
    ingressClassName: internal
    annotations:
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    extraTls:
      - hosts:
        - argocd.mikael.localhost
        # Based on the ingress controller used secret might be optional
        secretName: argocd-tls
```