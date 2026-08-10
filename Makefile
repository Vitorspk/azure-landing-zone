.PHONY: help deploy-all destroy-all iam-apply network-apply k8s-apply fmt lint validate

help:
	@echo 'Usage: make [target]'
	@echo 'Targets:'
	@echo '  deploy-all    - Deploy all modules'
	@echo '  destroy-all   - Destroy all modules'
	@echo '  iam-apply     - Deploy IAM module'
	@echo '  network-apply - Deploy Network module'
	@echo '  k8s-apply     - Deploy Kubernetes module'
	@echo '  fmt           - Format all Terraform files'
	@echo '  lint          - Run tflint on every module'
	@echo '  validate      - Run terraform validate on every module'

deploy-all:
	cd terraform/00-iam && terraform init && terraform apply -auto-approve
	cd terraform/01-networking && terraform init && terraform apply -auto-approve
	cd terraform/02-kubernetes && terraform init && terraform apply -auto-approve

destroy-all:
	cd terraform/02-kubernetes && terraform destroy -auto-approve
	cd terraform/01-networking && terraform destroy -auto-approve
	cd terraform/00-iam && terraform destroy -auto-approve

iam-apply:
	cd terraform/00-iam && terraform init && terraform apply -auto-approve

network-apply:
	cd terraform/01-networking && terraform init && terraform apply -auto-approve

k8s-apply:
	cd terraform/02-kubernetes && terraform init && terraform apply -auto-approve

fmt:
	terraform fmt -recursive terraform/

lint:
	@for m in 00-iam 01-networking 02-kubernetes 02-kubernetes/modules/aks-cluster; do \
		echo "=== $$m ==="; \
		(cd terraform/$$m && tflint --init --config="$$(git rev-parse --show-toplevel)/.tflint.hcl" 2>/dev/null; tflint --config="$$(git rev-parse --show-toplevel)/.tflint.hcl") || exit 1; \
	done

validate:
	@for m in 00-iam 01-networking 02-kubernetes 02-kubernetes/modules/aks-cluster; do \
		echo "=== $$m ==="; \
		(cd terraform/$$m && terraform init -backend=false -input=false >/dev/null && terraform validate) || exit 1; \
	done
