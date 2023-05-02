```
# macos

# install deps
brew tap hashicorp/tap
brew install colima docker kind kubectl helm helmfile jq terraform

# start container runtimes
colima start

# create k8s cluster
kind create cluster --config config.yaml

# deploy helm apps
helmfile apply

# init vault
kubectl -n vault exec vault-0 -- vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json > cluster-keys.json

# get unseal key
VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)

# unseal vault-0
kubectl -n vault exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

# expose vault service
kubectl -n vault port-forward services/vault-active 8200

# in second terminal
# create pg cluster
kubectl apply -f demo-pg-cluster.yaml

# get root token
export VAULT_TOKEN=$(jq -r ".root_token" cluster-keys.json)

# get pg superuser password
export TF_VAR_pg_superuser_password=$(kubectl get secrets demo-cluster-superuser -o jsonpath={.data.password} | base64 -d)

# terraform apply
cd terraform
terraform init
terraform apply

# test
kubectl create serviceaccount app-auth
kubectl apply -f ../app.yaml
kubectl exec -it app -c app -- cat /vault/secrets/credentials.txt
