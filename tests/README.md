# Testing Infrastructure

## Purpose
This directory contains comprehensive testing infrastructure for validating NixOS configurations, Ansible roles, and OpenTofu/Terraform infrastructure code.

## Contents
- **nixos/** - NixOS VM tests using the nixosTest framework
- **ansible/** - Ansible role tests using Molecule framework
- OpenTofu/Terraform validation tests (to be added)

## Usage
Tests are executed:
- Locally during development (via justfile recipes)
- In CI/CD pipelines on pull requests
- Before production deployments as validation gates
- After infrastructure changes to verify functionality

## Standards
- Target 80% test coverage for critical paths
- All tests must be idempotent and repeatable
- Use descriptive test names that explain what is being tested
- Include both positive and negative test cases
- Document test prerequisites and dependencies
