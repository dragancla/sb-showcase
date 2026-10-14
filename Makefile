TAG ?= 1.0.0
NAMESPACE ?= sb
CHART_DIR ?= ./charts/sb

.PHONY: help
help: ## Display available commands
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# -------
# K8s 
# -------

.PHONY: minikube-up
minikube-up: ## Start Minikube
	@echo "\n\033[1;34m==> [1/5] Checking Minikube status...\033[0m"
	@minikube status >/dev/null 2>&1 || minikube start --driver=docker --cpus=2 --memory=4096
	@minikube update-context
	@kubectl config use-context minikube >/dev/null
	@echo "Minikube control plane is healthy and active."

.PHONY: build-images
build-images: ## Build container images
	@echo "\n\033[1;34m==> [2/5] Building Docker images on host...\033[0m"
	docker build -q -t ghcr.io/anton-dragan/sb-backend:$(TAG) ./apps/backend
	docker build -q -t ghcr.io/anton-dragan/sb-frontend:$(TAG) ./apps/frontend
	@echo "Images successfully built."

.PHONY: load-images
load-images: build-images ## Load images into Minikube 
	@echo "\n\033[1;34m==> [3/5] Sideloading images into Minikube runtime...\033[0m"
	minikube image load ghcr.io/anton-dragan/sb-backend:$(TAG)
	minikube image load ghcr.io/anton-dragan/sb-frontend:$(TAG)
	@echo "Images successfully cached in Minikube."

.PHONY: lint-helm
lint-helm: ## Helm lint validation
	@echo "\n\033[1;34m==> [4/5] Running pre-flight Helm linting and template checks...\033[0m"
	@helm lint $(CHART_DIR)
	@helm template sb $(CHART_DIR) -n $(NAMESPACE) --debug > /dev/null
	@echo "Helm chart manifests are valid."

.PHONY: status-k8s
status-k8s: ## Show K8s status of pods, services and secrets
	@echo "\n--- KUBERNETES WORKLOADS (Namespace: $(NAMESPACE)) ---"
	@kubectl get pods,svc,secret -n $(NAMESPACE)

.PHONY: test-k8s
test-k8s: ## Test deeployed backend
	@echo "\n==> Running health check on backend API..."
	@kubectl port-forward -n $(NAMESPACE) svc/backend 8080:8080 >/dev/null 2>&1 & PID=$$!; \
	sleep 2; \
	curl -s http://localhost:8080/healthz | grep -q "healthy" && echo "\033[1;32mBackend healthcheck PASSED\033[0m" || echo "\033[1;31mBackend healthcheck FAILED\033[0m"; \
	curl -s http://localhost:8080/api/data; \
	echo ""; \
	kill $$PID 2>/dev/null

.PHONY: port-forward
port-forward: ## Open tunnel to frontend
	@echo "\n\033[1;32m==> App is live! Open your browser at: http://localhost:8080\033[0m"
	@echo "==> Streaming traffic (Press Ctrl+C to close the tunnel)..."
	@kubectl port-forward -n $(NAMESPACE) svc/sb-frontend 8080:8080

.PHONY: deploy-k8s
deploy-k8s: minikube-up build-images load-images lint-helm ## Automated K8s deployment via Helm
	@echo "\n\033[1;34m==> [5/5] Deploying Helm release 'sb' into namespace '$(NAMESPACE)'...\033[0m"
	helm upgrade --install sb $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 120s
	@echo "\n\033[1;32m==> Kubernetes deployment successfully verified!\033[0m"
	@make status-k8s test-k8s port-forward

.PHONY: destroy-k8s
destroy-k8s: ## Teardown K8s
	@echo "==> Tearing down Helm release and namespace '$(NAMESPACE)'..."
	@helm uninstall sb -n $(NAMESPACE) 2>/dev/null || true
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@minikube delete
	@echo "Kubernetes resources removed."

# -------
# NOMAD 
# -------

.PHONY: docker-network
docker-network: ## Ensure Docker network 
	@echo "\n\033[1;34m==> [1/5] Ensuring Docker network 'sb' exists...\033[0m"
	@docker network inspect sb >/dev/null 2>&1 || docker network create sb >/dev/null
	@make clean-port

.PHONY: clean-port
clean-port: ## Clean up Docker containers and network
	@echo "==> Cleaning up port 8080"
	@kill -9 $(lsof -ti :8080) 2>/dev/null || true

.PHONY: deploy-nomad
deploy-nomad: docker-network build-images ## Validate and run Nomad
	# Needs nomad agent -dev -bind 0.0.0.0 -config=nomad-jobs/nomad-dev.hcl    
	@echo "\n\033[1;34m==> [3/5] Validating Nomad job...\033[0m"
	nomad job validate nomad-jobs/sb.nomad.hcl
	@echo "\n\033[1;34m==> [4/5] ==> Running Nomad job...\033[0m"
	nomad job run nomad-jobs/sb.nomad.hcl
	@echo "\n\033[1;34m==> [5/5] ==> Checking status...\033[0m"
	@nomad job status sb

.PHONY: destroy-nomad
destroy-nomad: ## Teardown Nlomad
	@nomad job stop -purge sb
	@make clean-port

# -------
# TF 
# -------

.PHONY: status-all
status-all: ## View status across both platforms
	@echo "\n--- KUBERNETES WORKLOADS (Namespace: sb) ---"
	@kubectl get pods,svc,secret -n sb
	@echo "\n--- HASHICORP NOMAD WORKLOADS ---"
	@nomad job status sb

.PHONY: deploy-tf
deploy-tf: minikube-up clean-port build-images load-images## Provision via Terraform
	@echo "\n\033[1;34m==> Ensuring Docker network 'sb' exists...\033[0m"
	@docker network inspect sb >/dev/null 2>&1 || docker network create sb >/dev/null
	@echo "\n\033[1;34m==> Initializing Terraform...\033[0m"
	@cd terraform && terraform init
	@echo "\n\033[1;34m==> Executing Terraform Apply across both schedulers...\033[0m"
	@cd terraform && terraform apply -auto-approve
	@echo "\n\033[1;32m==> Terraform dual-deployment complete!\033[0m"
	@make status-all

.PHONY: destroy-tf
destroy-tf: ## Teardown TF
	@echo "\n\033[1;34m==> Destroying Terraform resources...\033[0m"
	@cd terraform && terraform destroy -auto-approve
	@make clean-port
	@minikube delete
	@echo "\033[1;32m==> All resources destroyed and cleaned up.\033[0m"
