# CI/CD Workflows

## Purpose
This directory contains GitHub Actions workflow definitions for automated validation, testing, and deployment of infrastructure changes.

## Contents
- Pull request validation workflows
- Automated test execution (NixOS, Ansible, Terraform)
- Secrets validation and schema checks
- Linting and formatting checks
- Deployment automation workflows

## Usage
Workflows are triggered by:
- Pull requests (validation and testing)
- Pushes to main branch (integration tests)
- Manual workflow dispatch (deployments)
- Scheduled runs (drift detection, compliance checks)

## Standards
- Use GitHub Actions workflow syntax (YAML)
- Define clear workflow names and descriptions
- Use matrix strategy for multi-platform/multi-distribution testing
- Cache dependencies to improve workflow performance
- Require status checks to pass before merging
- Store secrets in GitHub repository secrets (not in workflow files)
