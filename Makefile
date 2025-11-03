.PHONY: help deploy-all destroy-all

help:
	@echo 'Usage: make [target]'
	@echo 'Targets:'
	@echo '  deploy-all    - Deploy all modules'
	@echo '  destroy-all   - Destroy all modules'
	@echo '  iam-apply     - Deploy IAM module'
	@echo '  network-apply - Deploy Network module'
	@echo '  k8s-apply     - Deploy Kubernetes module'

deploy-all:
	cd terraform/00-iam && terraform init && terraform apply -auto-approve
	cd terraform/01-networking && terraform init && terraform apply -auto-approve
	cd terraform/02-kubernetes && terraform init && terraform apply -auto-approve

destroy-all:
	cd terraform/02-kubernetes && terraform destroy -auto-approve
	cd terraform/01-networking && terraform destroy -auto-approve
	cd terraform/00-iam && terraform destroy -auto-approve

iam-apply:
	cd terraform/00-iam && terraform init && terraform apply

network-apply:
	cd terraform/01-networking && terraform init && terraform apply

k8s-apply:
	cd terraform/02-kubernetes && terraform init && terraform apply
