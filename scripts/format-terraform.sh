#!/bin/bash
set -e

echo "Formatting Terraform files..."
terraform fmt -recursive terraform/

echo "✓ Terraform files formatted successfully!"
