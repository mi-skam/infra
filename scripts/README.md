# Infrastructure Scripts

This directory contains utility scripts for managing infrastructure.

## VM Management

### create-vm-darwin.sh

Creates QEMU VM launcher scripts for macOS ARM64 machines.

**Usage:**
```bash
./create-vm-darwin.sh [vm_name]
```

If no name is provided, the script will prompt for one. The generated script (e.g., `vm1.sh`) will be placed in the current directory or `$BIN_PATH` if defined.

**Generated VM Script Features:**
- Dynamic port allocation for SSH and monitor access
- Automatic disk image creation
- Command-line options for customization
- Support for running in daemon mode
- Proper cleanup on termination

**VM Script Usage:**
```bash
./vm1.sh [options]
```

**Options:**
- `-i, --iso PATH`: Path to ISO file for installation
- `-m, --memory SIZE`: Memory size (default: 4G)
- `-c, --cpus NUM`: Number of CPUs (default: 4)
- `-s, --ssh-port PORT`: SSH port forwarding (random port if not specified)
- `-d, --daemon`: Run in daemon mode (background)
- `-h, --help`: Display help message

**Requirements:**
- QEMU installed via Homebrew
- macOS ARM64 (Apple Silicon)