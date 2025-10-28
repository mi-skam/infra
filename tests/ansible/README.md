# Ansible Role Tests

## Purpose
This directory contains Ansible role tests using the Molecule framework to verify role functionality, idempotency, and compatibility across different distributions.

## Contents
- Molecule scenarios for each role in ansible/roles/
- Test playbooks and verification scripts
- Docker-based test environments (Debian, Rocky, Ubuntu)
- Idempotency verification tests

## Usage
Ansible tests are executed with:
```bash
cd ansible/roles/role-name
molecule test
# or
molecule converge  # Run without destroying
molecule verify    # Run verification only
```

Tests verify:
- Role completes without errors
- Role is idempotent (changed=0 on second run)
- Configuration files are created correctly
- Services are running and responding
- Role works across target distributions

## Standards
- Use Molecule with Docker driver
- Test on all target distributions (Debian 12, Rocky 9, Ubuntu 24.04)
- Verify idempotency on every test run
- Include testinfra or ansible verification tasks
- Document role-specific test requirements
