# Vault Setup for webMethods Active Transfer (MFT) Deployment

This guide documents the complete setup and integration of HashiCorp Vault with the webMethods Active Transfer deployment.

## Quick Summary

- **Status**: ✅ All secrets created and agent sidecar operational
- **Secrets Stored**: mft-secrets, dcc-secrets, postgres-secrets, minio-secrets
- **Authentication Method**: Kubernetes Service Account via Kubernetes Auth
- **Integration Method**: Vault Agent Sidecar Injection
- **Secret Injection**: Automatic via pod annotations in mft-deploy.yaml
- **Vault Access**: Available at https://vault.sttlab.local (ingress configured)

## Architecture Overview

- **Vault Namespace**: `vault`
- **MFT Namespace**: `mft`
- **Vault Root Token**: `root-token` (dev mode only)
- **Vault Storage Path**: `secret/` (KV v2 secret engine)

## Prerequisites

- Vault CLI installed and configured
- Access to the Vault cluster
- Kubernetes context set to the cluster where Vault and MFT are deployed

## Secrets to Be Stored

### mft-secrets
MFT application database and admin credentials:

| Field | Value | Purpose |
|-------|-------|---------|
| `dbUrl` | `jdbc:wm:postgresql://postgres:5432;DatabaseName=mft` | JDBC connection pool (DVPool) |
| `dbUser` | `postgres` | Database user |
| `dbPassword` | `Password123@` | Database password |
| `adminPassword` | `manage` | MFT Administrator account |

### dcc-secrets
Data Connector (DCC) database credentials:

| Field | Value | Purpose |
|-------|-------|---------|
| `dbType` | `pgsql` | Database type identifier |
| `dbUrl` | `jdbc:wm:postgresql://postgres:5432;DatabaseName=mft` | Primary database connection |
| `dbUser` | `postgres` | Database user |
| `dbPassword` | `Password123@` | Database password |
| `dbArchUrl` | `jdbc:wm:postgresql://postgres:5432;DatabaseName=mft` | Archive database connection |
| `dbArchUser` | `postgres` | Archive database user |
| `dbArchPassword` | `Password123@` | Archive database password |

### postgres-secrets
PostgreSQL database credentials:

| Field | Value | Purpose |
|-------|-------|---------|
| `POSTGRES_PASSWORD` | `Password123@` | PostgreSQL password |
| `POSTGRES_USER` | `postgres` | PostgreSQL user |
| `POSTGRES_DB` | `mft` | Initial database name |

### minio-secrets
MinIO object storage credentials:

| Field | Value | Purpose |
|-------|-------|---------|
| `MINIO_ROOT_USER` | `admin` | MinIO root user |
| `MINIO_ROOT_PASSWORD` | `Password123@` | MinIO root password |

## Vault Authentication Setup

### Prerequisites for Kubernetes Auth

Before setting up the Vault Agent sidecar for MFT, Kubernetes authentication must be configured:

```bash
# Set Vault address
export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200

# Login with root token
vault login root-token

# Get Kubernetes cluster information
KUBE_HOST=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
KUBE_CA=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)
KUBE_TOKEN=$(kubectl create token vault -n vault --duration=8760h)

# Enable Kubernetes auth method
vault auth enable kubernetes

# Configure Kubernetes auth method
# IMPORTANT: Use kubernetes.default.svc.cluster.local for the host, NOT localhost or 127.0.0.1
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
  kubernetes_ca_cert="$KUBE_CA" \
  token_reviewer_jwt="$KUBE_TOKEN" \
  disable_iss_validation=true

# Create mft-policy for MFT access
vault policy write mft-policy - <<EOF
path "secret/*" {
  capabilities = ["read", "list"]
}
EOF

# Create mft-role for the MFT service account
vault write auth/kubernetes/role/mft-role \
  bound_service_account_names=mft-sa \
  bound_service_account_namespaces=mft \
  policies=mft-policy \
  ttl=24h
```

### Troubleshooting Kubernetes Auth

**Common Issue**: `permission denied` when authenticating

**Solution**: Ensure you're using `kubernetes.default.svc.cluster.local:443` (not `127.0.0.1:26443` or `localhost`)

The Kubernetes API must be reachable from inside the Vault container using the cluster DNS name.

## Vault CLI Setup

### 1. Login to Vault

```bash
# Set Vault address (adjust for your environment)
export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200

# Login with root token (dev mode)
vault login root-token
```

### 2. Create Secrets in Vault

#### Create mft-secrets

```bash
vault kv put secret/mft-secrets \
  dbUrl="jdbc:wm:postgresql://postgres:5432;DatabaseName=mft" \
  dbUser="postgres" \
  dbPassword="Password123@" \
  adminPassword="manage"
```

**Verification:**
```bash
vault kv get secret/mft-secrets
```

#### Create dcc-secrets

```bash
vault kv put secret/dcc-secrets \
  dbType="pgsql" \
  dbUrl="jdbc:wm:postgresql://postgres:5432;DatabaseName=mft" \
  dbUser="postgres" \
  dbPassword="Password123@" \
  dbArchUrl="jdbc:wm:postgresql://postgres:5432;DatabaseName=mft" \
  dbArchUser="postgres" \
  dbArchPassword="Password123@"
```

**Verification:**
```bash
vault kv get secret/dcc-secrets
```

#### Create postgres-secrets

```bash
vault kv put secret/postgres-secrets \
  POSTGRES_PASSWORD="Password123@" \
  POSTGRES_USER="postgres" \
  POSTGRES_DB="mft"
```

**Verification:**
```bash
vault kv get secret/postgres-secrets
```

#### Create minio-secrets

```bash
vault kv put secret/minio-secrets \
  MINIO_ROOT_USER="admin" \
  MINIO_ROOT_PASSWORD="Password123@"
```

**Verification:**
```bash
vault kv get secret/minio-secrets
```

### 3. Batch Create All Secrets

If you prefer to create all secrets at once, use this script:

```bash
#!/bin/bash
set -e

# Set Vault address
export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200

# Login
vault login root-token

# Create all secrets
vault kv put secret/mft-secrets \
  dbUrl="jdbc:wm:postgresql://postgres:5432;DatabaseName=mft" \
  dbUser="postgres" \
  dbPassword="Password123@" \
  adminPassword="manage"

vault kv put secret/dcc-secrets \
  dbType="pgsql" \
  dbUrl="jdbc:wm:postgresql://postgres:5432;DatabaseName=mft" \
  dbUser="postgres" \
  dbPassword="Password123@" \
  dbArchUrl="jdbc:wm:postgresql://postgres:5432;DatabaseName=mft" \
  dbArchUser="postgres" \
  dbArchPassword="Password123@"

vault kv put secret/postgres-secrets \
  POSTGRES_PASSWORD="Password123@" \
  POSTGRES_USER="postgres" \
  POSTGRES_DB="mft"

vault kv put secret/minio-secrets \
  MINIO_ROOT_USER="admin" \
  MINIO_ROOT_PASSWORD="Password123@"

echo "All secrets created successfully!"

# Verify all secrets
echo ""
echo "=== Verifying All Secrets ==="
vault kv get secret/mft-secrets
echo ""
vault kv get secret/dcc-secrets
echo ""
vault kv get secret/postgres-secrets
echo ""
vault kv get secret/minio-secrets
```

### 4. Verify All Secrets

```bash
# List all secrets
vault kv list secret/

# Get each secret
vault kv get secret/mft-secrets
vault kv get secret/dcc-secrets
vault kv get secret/postgres-secrets
vault kv get secret/minio-secrets
```

### 5. Retrieve Specific Secret Values

To extract individual secret values for use in scripts or applications:

```bash
# Get MFT database password
vault kv get -field=dbPassword secret/mft-secrets

# Get MFT admin password
vault kv get -field=adminPassword secret/mft-secrets

# Get PostgreSQL user
vault kv get -field=POSTGRES_USER secret/postgres-secrets

# Get MinIO root user
vault kv get -field=MINIO_ROOT_USER secret/minio-secrets
```

### 6. Update Secrets

To update an existing secret while preserving other fields:

```bash
# Update only the database password
vault kv patch secret/mft-secrets dbPassword="NewPassword123@"

# Update MFT admin password
vault kv patch secret/mft-secrets adminPassword="newadminpass"

# Update PostgreSQL password
vault kv patch secret/postgres-secrets POSTGRES_PASSWORD="NewPgPassword123@"
```

### 7. Delete Secrets (Use with Caution)

```bash
# Delete a specific secret (soft delete - keeps metadata)
vault kv metadata delete secret/mft-secrets

# Permanently delete all versions (hard delete)
vault kv metadata delete -force secret/mft-secrets
```

## Vault Agent Sidecar Injection

The Vault Agent Injector automatically injects secrets into Kubernetes pods using annotations. This is the recommended approach for the MFT deployment.

### How It Works

1. **Pod Creation**: When a pod with Vault Agent annotations is created
2. **Webhook Mutation**: The Vault Agent Injector webhook mutates the pod spec
3. **Init Container**: Adds an init container that authenticates and fetches secrets
4. **Sidecar Container**: Adds a sidecar that maintains token and watches for changes
5. **Secret Files**: Secrets are written to `/vault/secrets/` directory in the pod

### Configuration for MFT Deployment

The mft-deploy.yaml includes the following annotations:

```yaml
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "mft-role"
vault.hashicorp.com/agent-inject-status: "update"
vault.hashicorp.com/agent-inject-token: "true"
vault.hashicorp.com/agent-inject-secret-mft-secrets: "secret/mft-secrets"
vault.hashicorp.com/agent-inject-template-mft-secrets: |
  {{- with secret "secret/mft-secrets" -}}
  export DB_URL="{{ .Data.data.dbUrl }}"
  export DB_USER="{{ .Data.data.dbUser }}"
  export DB_PASSWORD="{{ .Data.data.dbPassword }}"
  export ADMIN_PASSWORD="{{ .Data.data.adminPassword }}"
  {{- end }}
```

### What Gets Injected

- **File Location**: `/vault/secrets/mft-secrets`
- **Format**: Bash-compatible environment variable exports
- **Accessible By**: The application container in the same pod
- **Refresh**: Updates automatically when secrets change in Vault

### Example Usage in Application

To use the injected secrets in the MFT container:

```bash
# Source the secrets file
source /vault/secrets/mft-secrets

# Use the environment variables
echo "Database URL: $DB_URL"
echo "Database User: $DB_USER"
echo "Admin Password: $ADMIN_PASSWORD"
```

### Verifying Agent Injection

```bash
# Get the MFT pod name
POD=$(kubectl get pods -n mft -l app.kubernetes.io/name=activetransfer -o jsonpath='{.items[0].metadata.name}')

# Check that sidecar is running
kubectl get pod -n mft $POD -o jsonpath='{.spec.containers[*].name}'

# Expected output: mft vault-agent

# View the injected secrets file
kubectl exec -n mft $POD -c mft -- cat /vault/secrets/mft-secrets

# View the vault agent logs
kubectl logs -n mft $POD -c vault-agent --tail=20
```

### Troubleshooting Agent Injection

**Issue**: Pod shows `0/2` containers running

**Diagnosis**: Check if the vault-agent init container failed
```bash
kubectl logs -n mft $POD -c vault-agent-init
```

**Common Errors**:
- `permission denied` - Check that mft-role exists and has correct policies
- `could not find a ready Vault instance` - Check VAULT_ADDR is correct
- `bad token claims` - Verify mft-sa service account exists in mft namespace

**Issue**: Secrets file not created

**Diagnosis**: Check template syntax in annotations
```bash
# Verify the annotation format
kubectl get pod -n mft $POD -o jsonpath='{.metadata.annotations.vault\.hashicorp\.com/agent-inject-template-mft-secrets}'
```

## Kubernetes Integration

### Option A: External Secrets Operator (ESO)

To automatically sync Vault secrets to Kubernetes, use External Secrets Operator. Install ESO first, then create:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: mft
spec:
  provider:
    vault:
      server: "https://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "mft-role"
      caProvider:
        key: ca.crt
        name: vault-ca
        type: ConfigMap
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mft-secrets
  namespace: mft
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: mft-secrets
    creationPolicy: Owner
  data:
  - secretKey: dbUrl
    remoteRef:
      key: mft-secrets
      property: dbUrl
  - secretKey: dbUser
    remoteRef:
      key: mft-secrets
      property: dbUser
  - secretKey: dbPassword
    remoteRef:
      key: mft-secrets
      property: dbPassword
  - secretKey: adminPassword
    remoteRef:
      key: mft-secrets
      property: adminPassword
```

### Option B: Vault Agent Sidecar Injection (Recommended for MFT)

**The MFT deployment uses this approach via Pod annotations.**

The Vault Agent Injector webhook automatically handles secret injection without needing to create Kubernetes secrets manually. See the [Vault Agent Sidecar Injection](#vault-agent-sidecar-injection) section above.

### Option C: Manual Secret Management

Create Kubernetes secrets from Vault values (not recommended, use Option B instead):

```bash
# Create mft-secrets from Vault
kubectl create secret generic mft-secrets \
  --from-literal=dbUrl="$(vault kv get -field=dbUrl secret/mft-secrets)" \
  --from-literal=dbUser="$(vault kv get -field=dbUser secret/mft-secrets)" \
  --from-literal=dbPassword="$(vault kv get -field=dbPassword secret/mft-secrets)" \
  --from-literal=adminPassword="$(vault kv get -field=adminPassword secret/mft-secrets)" \
  -n mft

# Create postgres-secrets from Vault
kubectl create secret generic postgres-secrets \
  --from-literal=POSTGRES_PASSWORD="$(vault kv get -field=POSTGRES_PASSWORD secret/postgres-secrets)" \
  --from-literal=POSTGRES_USER="$(vault kv get -field=POSTGRES_USER secret/postgres-secrets)" \
  --from-literal=POSTGRES_DB="$(vault kv get -field=POSTGRES_DB secret/postgres-secrets)" \
  -n mft

# Create minio-secrets from Vault
kubectl create secret generic minio-secrets \
  --from-literal=MINIO_ROOT_USER="$(vault kv get -field=MINIO_ROOT_USER secret/minio-secrets)" \
  --from-literal=MINIO_ROOT_PASSWORD="$(vault kv get -field=MINIO_ROOT_PASSWORD secret/minio-secrets)" \
  -n mft

# Create dcc-secrets from Vault
kubectl create secret generic dcc-secrets \
  --from-literal=dbType="$(vault kv get -field=dbType secret/dcc-secrets)" \
  --from-literal=dbUrl="$(vault kv get -field=dbUrl secret/dcc-secrets)" \
  --from-literal=dbUser="$(vault kv get -field=dbUser secret/dcc-secrets)" \
  --from-literal=dbPassword="$(vault kv get -field=dbPassword secret/dcc-secrets)" \
  --from-literal=dbArchUrl="$(vault kv get -field=dbArchUrl secret/dcc-secrets)" \
  --from-literal=dbArchUser="$(vault kv get -field=dbArchUser secret/dcc-secrets)" \
  --from-literal=dbArchPassword="$(vault kv get -field=dbArchPassword secret/dcc-secrets)" \
  -n mft
```

## Vault Audit and Security

### Enable Audit Logging

```bash
# Enable file audit logging
vault audit enable file file_path=/vault/logs/audit.log

# List enabled audit backends
vault audit list
```

### Verify Access Control

The mft-policy and mft-role were already created in the "Vault Authentication Setup" section. To verify they are configured correctly:

```bash
# Verify mft-policy
vault policy read mft-policy

# Verify mft-role
vault read auth/kubernetes/role/mft-role
```

## Production Recommendations

1. **Use HTTPS with TLS**: Replace `http://` with `https://` and configure proper CA certificates
2. **Implement Role-Based Access**: Create service account-specific policies instead of using root token
3. **Enable Audit Logging**: All access to secrets should be logged
4. **Rotate Secrets Regularly**: Implement a rotation policy for database and application passwords
5. **Use Secret Versioning**: Leverage Vault's versioning to track secret changes
6. **Backup Vault**: Regular snapshots of Vault data should be maintained
7. **High Availability**: Enable Vault HA mode for production deployments
8. **Disable Dev Mode**: Production Vault instances should not use dev mode (`dev.enabled: false`)

## Troubleshooting

### Kubernetes Auth Returns "permission denied"

**Cause**: Incorrect Kubernetes API host in auth config

**Solution**: Ensure you're using `kubernetes.default.svc.cluster.local:443` (not localhost)

```bash
vault read auth/kubernetes/config | grep kubernetes_host
# Should show: kubernetes_host    https://kubernetes.default.svc.cluster.local:443
```

### Cannot Connect to Vault

```bash
# Test connectivity to Vault
curl http://vault.vault.svc.cluster.local:8200/v1/sys/health

# Check Vault pod logs
kubectl logs -n vault vault-0 --tail=50

# Verify Vault service is running
kubectl get svc -n vault
```

### Agent Sidecar Not Injecting Secrets

```bash
# Check if webhook is running
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector

# Check webhook logs
kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector --tail=50

# Verify pod has annotations
POD=$(kubectl get pods -n mft -l app.kubernetes.io/name=activetransfer -o jsonpath='{.items[0].metadata.name}')
kubectl get pod -n mft $POD -o jsonpath='{.metadata.annotations}' | jq .
```

### MFT Pod Not Ready (0/2 containers)

```bash
# Check init container status
POD=$(kubectl get pods -n mft -l app.kubernetes.io/name=activetransfer -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n mft $POD -c vault-agent-init --tail=30

# Check pod events
kubectl describe pod -n mft $POD | tail -30
```

### Secrets File Not Created in Pod

```bash
# Verify the secret exists in Vault
vault kv get secret/mft-secrets

# Check the annotation template syntax
kubectl get pod -n mft $POD -o jsonpath='{.metadata.annotations."vault\.hashicorp\.com/agent-inject-template-mft-secrets"}'

# Manually verify agent can read the secret
POD=$(kubectl get pods -n mft -l app.kubernetes.io/name=activetransfer -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mft $POD -c vault-agent -- ls -la /vault/secrets/
```

### Vault CLI Command Reference

```bash
# Set environment
export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200

# Login
vault login root-token

# Check Kubernetes auth
vault auth list
vault read auth/kubernetes/config
vault read auth/kubernetes/role/mft-role

# Check policies
vault policy list
vault policy read mft-policy

# Check secrets
vault kv list secret/
vault kv get secret/mft-secrets

# Manually test Kubernetes auth
JWT=$(kubectl -n mft create token mft-sa --duration=1h)
curl -X PUT \
  -d "{\"jwt\":\"$JWT\",\"role\":\"mft-role\"}" \
  http://vault.vault.svc.cluster.local:8200/v1/auth/kubernetes/login
```

## References

- [Vault KV Secrets Engine Documentation](https://www.vaultproject.io/docs/secrets/kv)
- [Vault CLI Commands](https://www.vaultproject.io/docs/commands)
- [Kubernetes Auth Method](https://www.vaultproject.io/docs/auth/kubernetes)
- [Vault Agent Injector Documentation](https://www.vaultproject.io/docs/platform/k8s/injector)
- [Vault Agent Templates](https://www.vaultproject.io/docs/agent/template)
