#!/bin/bash

# SECURITY REMEDIATION SCRIPT
# This script helps you secure your repository after credentials exposure

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${RED}${BOLD}"
echo "=========================================="
echo "  SECURITY REMEDIATION REQUIRED"
echo "=========================================="
echo -e "${NC}"
echo ""

CLIENT_ID="1d93ab1e-2b08-44b1-b4ab-47b91717b12c"

echo -e "${YELLOW}⚠️  Azure credentials were found in: azure_credentials.json${NC}"
echo ""
echo "This file contains a client secret that should NEVER be committed to Git."
echo ""

# Check if file is tracked by git
if git ls-files --error-unmatch azure_credentials.json &>/dev/null; then
    echo -e "${RED}❌ CRITICAL: File is tracked by Git!${NC}"
    FILE_IN_GIT=true
else
    echo -e "${GREEN}✓ File is not tracked by Git${NC}"
    FILE_IN_GIT=false
fi

echo ""
echo "=========================================="
echo "  REMEDIATION STEPS"
echo "=========================================="
echo ""

# Step 1: Rotate credentials
echo -e "${BOLD}Step 1: Rotate Azure Service Principal Credentials${NC}"
echo ""
echo "Execute this command to generate a new client secret:"
echo ""
echo -e "${GREEN}az ad sp credential reset --id $CLIENT_ID${NC}"
echo ""
read -p "Have you rotated the credentials? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Please rotate credentials before continuing.${NC}"
    exit 1
fi

# Step 2: Update GitHub secrets
echo ""
echo -e "${BOLD}Step 2: Update GitHub Secrets${NC}"
echo ""
echo "You need to update these GitHub repository secrets with the NEW values:"
echo "  - AZURE_CLIENT_SECRET (the new secret from credential reset)"
echo "  - AZURE_CREDENTIALS (full JSON with new clientSecret)"
echo ""
read -p "Have you updated GitHub Secrets? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Remember to update GitHub secrets!${NC}"
fi

# Step 3: Remove from git if tracked
if [ "$FILE_IN_GIT" = true ]; then
    echo ""
    echo -e "${BOLD}Step 3: Remove from Git Tracking${NC}"
    echo ""
    echo "Removing azure_credentials.json from git..."
    
    git rm --cached azure_credentials.json
    
    echo -e "${GREEN}✓ File removed from git tracking${NC}"
    echo ""
    echo "You need to commit this change:"
    echo -e "${GREEN}git commit -m \"security: remove exposed credentials file\"${NC}"
    echo ""
fi

# Step 4: Delete local file
echo ""
echo -e "${BOLD}Step 4: Delete Local File${NC}"
echo ""
read -p "Delete azure_credentials.json from filesystem? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f azure_credentials.json
    echo -e "${GREEN}✓ File deleted${NC}"
fi

# Step 5: Check if pushed to GitHub
echo ""
echo -e "${BOLD}Step 5: Check GitHub Repository${NC}"
echo ""
echo "Checking if file was pushed to GitHub..."

if git log --all --full-history -- azure_credentials.json | grep -q "commit"; then
    echo -e "${RED}❌ CRITICAL: File exists in Git history!${NC}"
    echo ""
    echo "The file was committed to Git. You MUST clean the history:"
    echo ""
    echo "Option 1: Using git filter-repo (recommended):"
    echo -e "${GREEN}git filter-repo --path azure_credentials.json --invert-paths${NC}"
    echo ""
    echo "Option 2: Using BFG Repo-Cleaner:"
    echo -e "${GREEN}bfg --delete-files azure_credentials.json${NC}"
    echo -e "${GREEN}git reflog expire --expire=now --all${NC}"
    echo -e "${GREEN}git gc --prune=now --aggressive${NC}"
    echo ""
    echo "After cleaning history:"
    echo -e "${GREEN}git push --force --all${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: Force push will rewrite history for all collaborators!${NC}"
else
    echo -e "${GREEN}✓ File not found in Git history (never committed or already cleaned)${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}  VERIFICATION CHECKLIST${NC}"
echo "=========================================="
echo ""
echo "Verify you completed ALL steps:"
echo ""
echo "  [  ] 1. Rotated Service Principal credentials"
echo "  [  ] 2. Updated AZURE_CLIENT_SECRET in GitHub"
echo "  [  ] 3. Updated AZURE_CREDENTIALS in GitHub"
echo "  [  ] 4. Removed azure_credentials.json from git tracking"
echo "  [  ] 5. Deleted local azure_credentials.json file"
echo "  [  ] 6. Cleaned Git history (if file was committed)"
echo "  [  ] 7. Force pushed to GitHub (if history was cleaned)"
echo ""
echo "=========================================="
echo -e "${GREEN}  PREVENTION${NC}"
echo "=========================================="
echo ""
echo "To prevent this in the future:"
echo ""
echo "1. ✓ .gitignore already blocks azure_credentials.json"
echo "2. ✓ Use GitHub Secrets for all credentials"
echo "3. ✓ Never commit files with 'secret', 'key', or 'credentials' in name"
echo "4. ✓ Use environment variables (ARM_*) for local development"
echo ""
echo "For local authentication, use:"
echo -e "${GREEN}az login${NC}"
echo ""
echo "For CI/CD, use GitHub Secrets (already configured in workflows)."
echo ""
