# Validation Schemas

## Purpose
This directory contains validation schemas for secrets, configurations, and infrastructure state to enable automated validation and prevent deployment errors.

## Contents
- YAML/JSON schemas for SOPS-encrypted secrets
- Configuration validation schemas for Ansible variables
- OpenTofu/Terraform variable schemas
- Nix configuration schemas

## Usage
Schemas are used to:
- Validate secrets files before encryption (SOPS pre-commit)
- Verify Ansible inventory and variables structure
- Check OpenTofu variable definitions
- Ensure consistent configuration format across environments

## Standards
- Use JSON Schema format for validation rules
- Include clear descriptions for all fields
- Define required vs. optional fields
- Provide examples in schema comments
- Version schemas when making breaking changes
