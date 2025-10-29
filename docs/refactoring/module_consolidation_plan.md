# Module Consolidation Plan

**Document Version:** 1.0
**Plan Date:** 2025-10-29
**Author:** Claude Code (Sonnet 4.5)
**Purpose:** Detailed consolidation plan for Iteration 3 refactoring
**Scope:** Nix module consolidations, Ansible role extractions, shared library creation

---

## Executive Summary

This consolidation plan synthesizes findings from three analysis documents (Nix module analysis, Ansible role analysis, baseline report) to provide actionable refactoring guidance for Iteration 3. The plan prioritizes consolidations by impact (lines of code reduced) and risk (breaking change likelihood), ensuring safe, high-value improvements.

### Key Metrics

| Metric | Current Baseline | Post-I3 Target | Delta | % Change |
|--------|------------------|----------------|-------|----------|
| **Nix Module Metrics** |
| Total Nix module lines | 973 | ~730 | -243 | -25% |
| Code duplication rate | 18% (~160 lines) | <5% (~35 lines) | -125 lines | -78% |
| Shared library modules | 0 | 4 | +4 | +∞ |
| User account duplication | 80 lines (2 files) | 0 lines | -80 | -100% |
| **Ansible Role Metrics** |
| Roles with Galaxy structure | 0/3 (0%) | 5/5 (100%) | +5 | +100% |
| Bootstrap playbook lines | 96 | ≤30 | -66 | -69% |
| Hardcoded values | 8 | 0 | -8 | -100% |
| Role documentation (README.md) | 0/3 (0%) | 5/5 (100%) | +5 | +100% |
| Extractable role logic (lines) | 75 (in playbook) | 0 (moved to roles) | -75 | -100% |
| **Overall Impact** |
| Total consolidations identified | 12 | - | - | - |
| Estimated effort (hours) | - | 48-65 | - | - |
| Estimated calendar time | - | 2-3 weeks | - | - |

### Consolidation Summary

**Nix Module Consolidations:** 7 identified
- HIGH priority: 2 (110 lines saved, 3-5 hours effort)
- MEDIUM priority: 2 (40-45 lines saved, 5-7 hours effort)
- LOW priority: 3 (30-35 lines saved, 2-3 hours effort)

**Ansible Role Extractions:** 5 identified
- HIGH priority: 3 (75 lines extracted, 20-25 hours effort)
- MEDIUM priority: 2 (Galaxy structure, 15-20 hours effort)

**Total Lines Saved:** ~280 lines (15.5% of codebase)
**Total Lines Added (documentation, structure):** ~900 lines
**Net Change:** +620 lines (primarily documentation and shared libraries)

---

## 1. Prioritized Consolidation Matrix

This matrix ranks all consolidations by priority score: `Priority = (Impact × 10) / (Risk + 1)` where:
- Impact = Lines of code saved
- Risk = 1 (LOW), 2 (MEDIUM), 3 (HIGH)

| Priority Score | Consolidation | Component | Impact (Lines) | Risk | Effort (Hours) | Iteration | Section |
|----------------|---------------|-----------|----------------|------|----------------|-----------|---------|
| **800** | Create User Account Builder | Nix | 80 | LOW | 2-3 | I3.T2 | §2.1 |
| **375** | Extract Bootstrap to Roles | Ansible | 75 | MEDIUM | 20-25 | I3.T3 | §3.1 |
| **175** | Create System Common Library | Nix | 35 | MEDIUM | 1-2 | I3.T2 | §2.2 |
| **150** | Add Galaxy Structure | Ansible | 0 (quality) | MEDIUM | 15-20 | I3.T4 | §3.2 |
| **100** | Extract HM Config Helpers | Nix | 100 | HIGH | 4-6 | I3.T5 | §2.3 |
| **90** | Parameterize Hardcoded Values | Ansible | 0 (quality) | LOW | 5-7 | I3.T4 | §3.3 |
| **75** | Create Platform Utility | Nix | 15 | MEDIUM | 1 | I3.T5 | §2.4 |
| **50** | Standardize SOPS Pattern | Nix | 20 | HIGH | 2-3 | I3.T6 | §2.5 |
| **35** | Implement Monitoring Role | Ansible | 0 (new) | HIGH | 8-10 | I5+ | §3.4 |
| **30** | Standardize HM User Configs | Nix | 30 | HIGH | 1-2 | I3.T6 | §2.6 |
| **25** | Extract Timezone Config | Nix | 3 | LOW | 0.5 | I3.T2 | §2.7 |
| **20** | Extract Shell Config | Nix | 4 | LOW | 0.5 | I3.T2 | §2.7 |

**Legend:**
- Priority Score ≥300: CRITICAL PATH (must complete in I3.T2-T3)
- Priority Score 100-299: HIGH VALUE (should complete in I3.T4-T5)
- Priority Score <100: NICE TO HAVE (complete in I3.T6 or defer to I4+)

---

## 2. Nix Module Consolidations

### 2.1 Consolidation N1: Create User Account Builder (CRITICAL PATH)

**Priority Score:** 800 (Impact: 80 lines, Risk: LOW)
**Iteration:** I3.T2
**Effort:** 2-3 hours
**Dependencies:** None

#### Current State

**Problem:** 95% duplicate code across two user account modules.

**Affected Files:**
- `modules/users/mi-skam.nix` (44 lines, lines 1-44)
- `modules/users/plumps.nix` (43 lines, lines 1-43)

**Current Code Pattern:**
```nix
# modules/users/mi-skam.nix
{ lib, pkgs, config, ... }:

lib.mkMerge [
  {
    users.users.mi-skam = {
      uid = 1000;
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [ ../../secrets/authorized_keys ];
    };
  }
  (lib.mkIf pkgs.stdenv.isDarwin {
    users.users.mi-skam.home = "/Users/mi-skam";
  })
  (lib.mkIf pkgs.stdenv.isLinux {
    users.users.mi-skam = {
      description = "Maksim Bronsky";
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "docker" "audio" "video" "input" "libvirtd" "kvm" "adbusers" ];
      hashedPasswordFile = config.sops.secrets."mi-skam".path;
    };
    users.mutableUsers = false;
  })
]
```

**Duplication Evidence:**
- Structure: 100% identical across both files
- Logic: 100% identical (only values differ: username, uid, description, secretName)
- Platform handling: 100% identical (isDarwin/isLinux conditional blocks)
- Lines duplicated: ~40 lines × 2 files = 80 lines

#### Proposed Changes

**Create:** `modules/lib/mkUser.nix`

**Target Architecture:**
```nix
# modules/lib/mkUser.nix
{ lib, pkgs, config, ... }:

{
  mkUser = {
    name,
    uid,
    description ? name,
    secretName ? name,
    groups ? [
      "wheel"
      "networkmanager"
      "docker"
      "audio"
      "video"
      "input"
      "libvirtd"
      "kvm"
      "adbusers"
    ]
  }: lib.mkMerge [
    # Common configuration (both Darwin and Linux)
    {
      users.users.${name} = {
        inherit uid;
        shell = pkgs.fish;
        openssh.authorizedKeys.keyFiles = [ ../../secrets/authorized_keys ];
      };
    }

    # Darwin-specific configuration
    (lib.mkIf pkgs.stdenv.isDarwin {
      users.users.${name}.home = "/Users/${name}";
    })

    # Linux-specific configuration
    (lib.mkIf pkgs.stdenv.isLinux {
      users.users.${name} = {
        inherit description;
        isNormalUser = true;
        extraGroups = groups;
        hashedPasswordFile = config.sops.secrets."${secretName}".path;
      };
      users.mutableUsers = false;
    })
  ];
}
```

**After Refactoring:**
```nix
# modules/users/mi-skam.nix
{ lib, pkgs, config, ... }:

let
  userLib = import ../lib/mkUser.nix { inherit lib pkgs config; };
in

userLib.mkUser {
  name = "mi-skam";
  uid = 1000;
  description = "Maksim Bronsky";
  secretName = "mi-skam";
}
```

```nix
# modules/users/plumps.nix
{ lib, pkgs, config, ... }:

let
  userLib = import ../lib/mkUser.nix { inherit lib pkgs config; };
in

userLib.mkUser {
  name = "plumps";
  uid = 1001;
  description = "Maxime Plumps";
  secretName = "plumps";
}
```

**Lines After Refactoring:**
- `mkUser.nix`: ~45 lines (new shared library)
- `mi-skam.nix`: ~11 lines (was 44, saved 33)
- `plumps.nix`: ~11 lines (was 43, saved 32)
- **Total saved:** 80 - 45 = 35 net lines saved (plus eliminated 80 lines of duplication)

#### Step-by-Step Migration Procedure

**Step 1: Create Shared Library** (30 minutes)
1. Create directory: `mkdir -p modules/lib`
2. Create file: `modules/lib/mkUser.nix`
3. Copy template from "Proposed Changes" above
4. Stage with git: `git add modules/lib/mkUser.nix`

**Step 2: Refactor First User (mi-skam)** (45 minutes)
1. Test original configuration builds:
   ```bash
   sudo nixos-rebuild build --flake .#xmsi
   ```
2. Edit `modules/users/mi-skam.nix` with new pattern
3. Stage changes: `git add modules/users/mi-skam.nix`
4. Test new configuration builds:
   ```bash
   sudo nixos-rebuild build --flake .#xmsi
   ```
5. Compare outputs (should be identical):
   ```bash
   nix derivation show .#nixosConfigurations.xmsi.config.users.users.mi-skam
   ```

**Step 3: Refactor Second User (plumps)** (45 minutes)
1. Test original Darwin configuration:
   ```bash
   nix build .#darwinConfigurations.xbook.system --dry-run
   ```
2. Edit `modules/users/plumps.nix` with new pattern
3. Stage changes: `git add modules/users/plumps.nix`
4. Test new configuration builds:
   ```bash
   nix build .#darwinConfigurations.xbook.system --dry-run
   ```

**Step 4: End-to-End Validation** (30 minutes)
1. Build all affected configurations:
   ```bash
   nix build .#nixosConfigurations.xmsi.config.system.build.toplevel
   nix build .#darwinConfigurations.xbook.system
   nix build .#nixosConfigurations.srv-01.config.system.build.toplevel
   ```
2. Deploy to test system (xmsi):
   ```bash
   sudo nixos-rebuild test --flake .#xmsi
   ```
3. Verify user account:
   ```bash
   id mi-skam
   groups mi-skam
   getent passwd mi-skam
   ```
4. Verify SSH key permissions:
   ```bash
   cat /home/mi-skam/.ssh/authorized_keys
   ```
5. Verify SOPS password integration:
   ```bash
   ls -l /run/secrets/mi-skam
   ```

#### Testing Approach

**Unit Tests:**
- Build each configuration independently
- Compare derivation outputs before/after refactoring
- Verify user attributes match expected values

**Integration Tests:**
- Deploy to xmsi (NixOS) and verify user can login
- Deploy to xbook (Darwin) and verify user home directory
- Test SSH key authentication
- Verify SOPS password file is correctly linked

**Test Commands:**
```bash
# NixOS test
sudo nixos-rebuild build-vm --flake .#xmsi
# Boot VM and verify: id mi-skam, groups mi-skam, ssh access

# Darwin test
darwin-rebuild check --flake .#xbook
# Verify: dscl . -read /Users/plumps

# Dry-run comparison
nix build .#nixosConfigurations.xmsi.config.system.build.toplevel --dry-run > before.txt
# (after refactoring)
nix build .#nixosConfigurations.xmsi.config.system.build.toplevel --dry-run > after.txt
diff before.txt after.txt  # Should show no functional changes
```

#### Rollback Plan

**If refactoring introduces issues:**

1. **Immediate rollback (Git):**
   ```bash
   git checkout modules/users/mi-skam.nix modules/users/plumps.nix
   git rm -r modules/lib/
   sudo nixos-rebuild switch --flake .#xmsi
   ```

2. **NixOS generation rollback:**
   ```bash
   # List generations
   sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

   # Rollback to previous
   sudo nixos-rebuild switch --rollback
   ```

3. **Darwin rollback:**
   ```bash
   # List generations
   darwin-rebuild --list-generations

   # Rollback to previous
   darwin-rebuild --rollback
   ```

**Rollback triggers:**
- User account creation fails
- SSH key permissions incorrect
- SOPS password integration broken
- Group memberships missing

#### Success Metrics

- [ ] `modules/lib/mkUser.nix` created and builds successfully
- [ ] `modules/users/mi-skam.nix` reduced from 44 to ~11 lines
- [ ] `modules/users/plumps.nix` reduced from 43 to ~11 lines
- [ ] All 3 affected configurations build without errors
- [ ] NixOS system (xmsi) deploys successfully with mi-skam user
- [ ] Darwin system (xbook) deploys successfully with plumps user
- [ ] 80 lines of duplication eliminated
- [ ] Zero functional changes (outputs identical)

---

### 2.2 Consolidation N2: Create System Common Library (CRITICAL PATH)

**Priority Score:** 175 (Impact: 35 lines, Risk: MEDIUM)
**Iteration:** I3.T2
**Effort:** 1-2 hours
**Dependencies:** None

#### Current State

**Problem:** System configuration boilerplate duplicated across NixOS and Darwin.

**Affected Files:**
- `modules/nixos/common.nix` (lines 12-17, 22, 39-40)
- `modules/darwin/common.nix` (lines 12-16, 18, 26-27)

**Current Code (duplicated patterns):**

Pattern 1 - Nix Experimental Features:
```nix
# nixos/common.nix:12-17, darwin/common.nix:12-16
nix.settings.experimental-features = [
  "nix-command"
  "flakes"
];

nixpkgs.config.allowUnfree = true;
```

Pattern 2 - Timezone:
```nix
# nixos/common.nix:22
time.timeZone = "Europe/Berlin";

# darwin/common.nix:18 (implicit, via system defaults)
system.defaults.NSGlobalDomain.AppleMeasurementUnits = "Centimeters";
```

Pattern 3 - Shell Configuration:
```nix
# nixos/common.nix:39-40, darwin/common.nix:26-27
programs.fish.enable = true;
programs.command-not-found.enable = false;
```

**Total Duplication:** 5 + 3 + 2 = 10 lines per file × 2 files = 20 lines, plus structural overhead = ~35 lines total

#### Proposed Changes

**Create:** `modules/lib/system-common.nix`

```nix
# modules/lib/system-common.nix
{ lib, pkgs, ... }:
{
  # Nix configuration
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Timezone (platform-specific implementation)
  time.timeZone = lib.mkIf pkgs.stdenv.isLinux (lib.mkDefault "Europe/Berlin");

  # Shell configuration
  programs.fish.enable = true;
  programs.command-not-found.enable = false;
}
```

**After Refactoring:**

```nix
# modules/nixos/common.nix (lines 12-40 replaced with 1 import)
{ lib, config, inputs, ... }:

{
  imports = [
    ../lib/system-common.nix
    inputs.srvos.nixosModules.common
    inputs.sops-nix.nixosModules.sops
    ./secrets.nix
    ../users/mi-skam.nix
    ../users/plumps.nix
  ];

  # NixOS-specific configuration continues...
  nix.settings.trusted-users = [ "root" "@wheel" ];
  # ... rest of file unchanged
}
```

```nix
# modules/darwin/common.nix (lines 12-27 replaced with 1 import)
{ lib, config, inputs, ... }:

{
  imports = [
    ../lib/system-common.nix
    inputs.sops-nix.darwinModules.sops
    ./secrets.nix
    ../users/plumps.nix
  ];

  # Darwin-specific configuration continues...
  system.defaults.NSGlobalDomain.AppleMeasurementUnits = "Centimeters";
  # ... rest of file unchanged
}
```

**Lines After Refactoring:**
- `system-common.nix`: ~20 lines (new)
- `nixos/common.nix`: 57 → ~42 lines (saved 15)
- `darwin/common.nix`: 41 → ~26 lines (saved 15)
- **Total saved:** 30 - 20 = 10 net lines saved (plus eliminated 30 lines of duplication)

#### Step-by-Step Migration Procedure

**Step 1: Create Shared Library** (15 minutes)
1. Create `modules/lib/system-common.nix` with content above
2. Stage with git: `git add modules/lib/system-common.nix`

**Step 2: Refactor NixOS Common** (20 minutes)
1. Test original: `sudo nixos-rebuild build --flake .#xmsi`
2. Edit `modules/nixos/common.nix`:
   - Add import: `../lib/system-common.nix`
   - Remove lines 12-17 (nix settings, allowUnfree)
   - Remove line 22 (timezone)
   - Remove lines 39-40 (fish, command-not-found)
3. Stage: `git add modules/nixos/common.nix`
4. Test: `sudo nixos-rebuild build --flake .#xmsi`

**Step 3: Refactor Darwin Common** (20 minutes)
1. Test original: `nix build .#darwinConfigurations.xbook.system --dry-run`
2. Edit `modules/darwin/common.nix`:
   - Add import: `../lib/system-common.nix`
   - Remove lines 12-16 (nix settings, allowUnfree)
   - Remove lines 26-27 (fish, command-not-found)
3. Stage: `git add modules/darwin/common.nix`
4. Test: `nix build .#darwinConfigurations.xbook.system --dry-run`

**Step 4: Validation** (15 minutes)
1. Build all affected systems:
   ```bash
   nix build .#nixosConfigurations.xmsi.config.system.build.toplevel
   nix build .#nixosConfigurations.srv-01.config.system.build.toplevel
   nix build .#darwinConfigurations.xbook.system
   ```
2. Verify nix experimental features enabled:
   ```bash
   nix show-config | grep experimental-features
   ```
3. Verify allowUnfree works:
   ```bash
   nix eval .#nixosConfigurations.xmsi.config.nixpkgs.config.allowUnfree
   # Should output: true
   ```

#### Testing Approach

**Unit Tests:**
```bash
# Test system-common.nix imports correctly
nix eval --raw .#nixosConfigurations.xmsi.config.nix.settings.experimental-features
# Expected: [ "nix-command" "flakes" ]

nix eval --raw .#nixosConfigurations.xmsi.config.time.timeZone
# Expected: "Europe/Berlin"

nix eval --raw .#nixosConfigurations.xmsi.config.programs.fish.enable
# Expected: true
```

**Integration Tests:**
- Deploy to xmsi and verify nix flakes work
- Verify unfree packages install (e.g., vscode)
- Verify timezone is Europe/Berlin: `timedatectl`
- Verify fish shell is available: `which fish`

#### Rollback Plan

**If refactoring introduces issues:**

1. **Git rollback:**
   ```bash
   git checkout modules/nixos/common.nix modules/darwin/common.nix
   git rm modules/lib/system-common.nix
   sudo nixos-rebuild switch --flake .#xmsi
   ```

2. **NixOS generation rollback:**
   ```bash
   sudo nixos-rebuild switch --rollback
   ```

**Rollback triggers:**
- Nix flakes stop working
- Unfree packages fail to install
- Timezone configuration incorrect
- Fish shell not available

#### Success Metrics

- [ ] `modules/lib/system-common.nix` created and imports successfully
- [ ] `modules/nixos/common.nix` reduced by ~15 lines
- [ ] `modules/darwin/common.nix` reduced by ~15 lines
- [ ] All 3 system configurations build without errors
- [ ] Nix experimental features enabled on all systems
- [ ] allowUnfree works on all systems
- [ ] Timezone correct on NixOS systems
- [ ] Fish shell enabled on all systems
- [ ] 30 lines of duplication eliminated

---

### 2.3 Consolidation N3: Extract Home Manager Config Helpers (HIGH VALUE)

**Priority Score:** 100 (Impact: 100 lines, Risk: HIGH)
**Iteration:** I3.T5
**Effort:** 4-6 hours
**Dependencies:** None

#### Current State

**Problem:** `modules/home/common.nix` is 264 lines with large embedded configurations for neovim (~60 lines) and starship (~35 lines). These are not reusable across users and make the common module difficult to maintain.

**Affected Files:**
- `modules/home/common.nix` (lines 116-178: neovim, lines 181-215: starship)

**Current Code Patterns:**

Neovim configuration (lines 116-178):
```nix
programs.neovim = {
  enable = true;
  viAlias = true;
  vimAlias = true;
  vimdiffAlias = true;

  extraConfig = ''
    set number
    set relativenumber
    set expandtab
    set tabstop=2
    set shiftwidth=2
    set autoindent
    set smartindent
    # ... 40+ more lines of vimscript
  '';

  plugins = with pkgs.vimPlugins; [
    vim-nix
    catppuccin-nvim
    nvim-treesitter
    # ... 10+ more plugins
  ];
};
```

Starship configuration (lines 181-215):
```nix
programs.starship = {
  enable = true;
  settings = {
    format = lib.concatStrings [
      "[┌───────────────────>](bold green)"
      "$directory"
      "$git_branch"
      # ... 20+ more format tokens
    ];
    palette = "catppuccin_mocha";
    palettes.catppuccin_mocha = {
      rosewater = "#f5e0dc";
      # ... 20+ color definitions
    };
  };
};
```

**Total Lines to Extract:** ~95 lines (60 neovim + 35 starship)

#### Proposed Changes

**Create:** `modules/lib/hm-helpers.nix`

```nix
# modules/lib/hm-helpers.nix
{ pkgs, lib, ... }:

{
  # Common CLI packages
  cliPackages = with pkgs; [
    bat
    eza
    fd
    fzf
    gh
    jq
    ripgrep
    tree
    unzip
    zip
    curl
    wget
    httpie
  ];

  # Neovim configuration builder
  mkNeovimConfig = { theme ? "catppuccin-mocha" }: {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraConfig = ''
      " Basic settings
      set number
      set relativenumber
      set expandtab
      set tabstop=2
      set shiftwidth=2
      set autoindent
      set smartindent
      set mouse=a
      set clipboard=unnamedplus
      set ignorecase
      set smartcase
      set incsearch
      set hlsearch
      set termguicolors
      set cursorline
      set scrolloff=8
      set signcolumn=yes
      set updatetime=50
      set timeoutlen=300

      " Theme
      colorscheme ${theme}

      " Key mappings
      let mapleader = " "
      nnoremap <leader>w :w<CR>
      nnoremap <leader>q :q<CR>
      nnoremap <C-h> <C-w>h
      nnoremap <C-j> <C-w>j
      nnoremap <C-k> <C-w>k
      nnoremap <C-l> <C-w>l
    '';

    plugins = with pkgs.vimPlugins; [
      vim-nix
      catppuccin-nvim
      nvim-treesitter
      telescope-nvim
      nvim-lspconfig
      nvim-cmp
      cmp-nvim-lsp
      luasnip
      friendly-snippets
    ];
  };

  # Starship configuration builder
  mkStarshipConfig = { palette ? "catppuccin_mocha" }: {
    enable = true;
    settings = {
      format = lib.concatStrings [
        "[┌───────────────────>](bold green)"
        "$directory"
        "$git_branch"
        "$git_state"
        "$git_status"
        "$cmd_duration"
        "$line_break"
        "[└─>](bold green) "
      ];

      directory = {
        style = "blue bold";
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = " ";
        style = "purple bold";
      };

      git_status = {
        style = "yellow bold";
        ahead = "⇡\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        behind = "⇣\${count}";
      };

      cmd_duration = {
        min_time = 500;
        format = "took [$duration](yellow bold)";
      };

      palette = palette;

      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
      };
    };
  };
}
```

**After Refactoring:**

```nix
# modules/home/common.nix (reduced from 264 to ~170 lines)
{ config, pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # Import helper functions
  hmHelpers = import ../lib/hm-helpers.nix { inherit pkgs lib; };
in
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ./syncthing.nix
    ./ssh.nix
    ./secrets.nix
  ];

  # Use helper packages
  home.packages = hmHelpers.cliPackages ++ [
    # Additional packages...
  ];

  # Use helper configurations
  programs.neovim = hmHelpers.mkNeovimConfig {};
  programs.starship = hmHelpers.mkStarshipConfig {};

  # Rest of common.nix continues...
}
```

**Lines After Refactoring:**
- `hm-helpers.nix`: ~120 lines (new shared library)
- `home/common.nix`: 264 → ~170 lines (saved 94)
- **Total saved:** 94 - 120 = -26 net lines (trade-off: more files, better organization)

#### Step-by-Step Migration Procedure

**Step 1: Create Shared Library** (1 hour)
1. Create `modules/lib/hm-helpers.nix`
2. Copy neovim config from `common.nix:116-178` into `mkNeovimConfig`
3. Copy starship config from `common.nix:181-215` into `mkStarshipConfig`
4. Extract package list into `cliPackages`
5. Stage: `git add modules/lib/hm-helpers.nix`

**Step 2: Test Helpers in Isolation** (1 hour)
1. Create test configuration:
   ```nix
   # test-helpers.nix
   let
     pkgs = import <nixpkgs> {};
     lib = pkgs.lib;
     helpers = import ./modules/lib/hm-helpers.nix { inherit pkgs lib; };
   in
   {
     neovim = helpers.mkNeovimConfig {};
     starship = helpers.mkStarshipConfig {};
     packages = helpers.cliPackages;
   }
   ```
2. Evaluate: `nix eval --json -f test-helpers.nix`
3. Verify no errors

**Step 3: Refactor Home Common** (1.5 hours)
1. Test original: `home-manager build --flake .#mi-skam@xmsi`
2. Edit `modules/home/common.nix`:
   - Add import: `hmHelpers = import ../lib/hm-helpers.nix { inherit pkgs lib; };`
   - Replace neovim config with: `programs.neovim = hmHelpers.mkNeovimConfig {};`
   - Replace starship config with: `programs.starship = hmHelpers.mkStarshipConfig {};`
   - Replace package list with: `home.packages = hmHelpers.cliPackages ++ [ ... ];`
3. Stage: `git add modules/home/common.nix`
4. Test: `home-manager build --flake .#mi-skam@xmsi`

**Step 4: Validation** (1.5 hours)
1. Build all home configurations:
   ```bash
   home-manager build --flake .#mi-skam@xmsi
   home-manager build --flake .#plumps@xbook
   home-manager build --flake .#plumps@srv-01
   ```
2. Deploy to test system:
   ```bash
   home-manager switch --flake .#mi-skam@xmsi
   ```
3. Test neovim:
   ```bash
   nvim --version
   nvim  # Check theme, plugins load
   ```
4. Test starship:
   ```bash
   echo $STARSHIP_CONFIG
   # Verify prompt renders correctly
   ```

#### Testing Approach

**Unit Tests:**
```bash
# Test neovim configuration
nix eval --raw .#homeConfigurations."mi-skam@xmsi".config.programs.neovim.enable
# Expected: true

# Test starship configuration
nix eval --json .#homeConfigurations."mi-skam@xmsi".config.programs.starship.settings
# Verify palette exists

# Test package list
nix eval --json .#homeConfigurations."mi-skam@xmsi".config.home.packages | jq 'length'
# Verify count matches expected
```

**Integration Tests:**
- Deploy to xmsi and launch neovim
- Verify plugins load correctly
- Verify colorscheme applies
- Test starship prompt renders
- Verify CLI packages installed

**Functional Tests:**
```bash
# Test neovim plugins
nvim -c "checkhealth"

# Test starship git integration
cd /tmp && git init test-repo && cd test-repo
# Verify git branch shown in prompt

# Test CLI packages
bat --version
eza --version
fzf --version
```

#### Rollback Plan

**If refactoring introduces issues:**

1. **Git rollback:**
   ```bash
   git checkout modules/home/common.nix
   git rm modules/lib/hm-helpers.nix
   home-manager switch --flake .#mi-skam@xmsi
   ```

2. **Home Manager generation rollback:**
   ```bash
   home-manager generations
   /nix/var/nix/profiles/per-user/$USER/home-manager-X-link/activate
   ```

**Rollback triggers:**
- Neovim plugins fail to load
- Starship prompt doesn't render
- Missing CLI packages
- Colorscheme not applied
- Performance degradation

#### Success Metrics

- [ ] `modules/lib/hm-helpers.nix` created with 3 functions
- [ ] `modules/home/common.nix` reduced from 264 to ~170 lines
- [ ] All 3 home configurations build without errors
- [ ] Neovim launches with correct theme and plugins
- [ ] Starship prompt renders correctly
- [ ] All CLI packages installed
- [ ] 94 lines extracted (reusable for other users)
- [ ] Zero functional changes to neovim or starship behavior

---

### 2.4 Consolidation N4: Create Platform Detection Utility (NICE TO HAVE)

**Priority Score:** 75 (Impact: 15 lines, Risk: MEDIUM)
**Iteration:** I3.T5
**Effort:** 1 hour
**Dependencies:** None

#### Current State

**Problem:** Platform detection let bindings repeated across 6+ modules.

**Affected Files:**
- `modules/home/common.nix` (lines 10-13)
- `modules/home/desktop.nix` (lines 10-13)
- `modules/home/dev.nix` (lines 10-13)
- `modules/home/syncthing.nix` (line 6, inline)
- `modules/home/wireguard.nix` (line 5, inline)
- `modules/home/qbittorrent.nix` (line 5, inline)

**Current Code:**
```nix
# Repeated in multiple files
let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
```

**Total Duplication:** 3 lines × 6 files = 18 lines

#### Proposed Changes

**Create:** `modules/lib/platform.nix`

```nix
# modules/lib/platform.nix
{ pkgs, ... }:

{
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  isAarch64 = pkgs.stdenv.isAarch64;
  isx86_64 = pkgs.stdenv.isx86_64;
}
```

**After Refactoring:**

```nix
# modules/home/common.nix (lines 10-13 replaced)
{ config, pkgs, lib, ... }:

let
  platform = import ../lib/platform.nix { inherit pkgs; };
in
{
  # Use platform.isDarwin, platform.isLinux
  home.homeDirectory =
    if platform.isDarwin
    then "/Users/${config.username}"
    else "/home/${config.username}";
}
```

**Lines Saved:** ~3 lines per module × 6 modules = 18 lines saved, minus 8-line library = 10 net lines saved

#### Step-by-Step Migration Procedure

**Step 1: Create Shared Library** (10 minutes)
1. Create `modules/lib/platform.nix` with content above
2. Stage: `git add modules/lib/platform.nix`

**Step 2: Refactor Modules One by One** (40 minutes)
1. For each module (`common.nix`, `desktop.nix`, `dev.nix`, `syncthing.nix`, `wireguard.nix`, `qbittorrent.nix`):
   - Replace `let isDarwin = pkgs.stdenv.isDarwin; isLinux = pkgs.stdenv.isLinux; in`
   - With: `let platform = import ../lib/platform.nix { inherit pkgs; }; in`
   - Replace all `isDarwin` with `platform.isDarwin`
   - Replace all `isLinux` with `platform.isLinux`
2. Stage: `git add modules/home/*.nix`

**Step 3: Validation** (10 minutes)
```bash
home-manager build --flake .#mi-skam@xmsi
home-manager build --flake .#plumps@xbook
```

#### Testing Approach

**Unit Tests:**
```bash
# Verify platform detection works
nix eval --raw .#homeConfigurations."mi-skam@xmsi".config.home.homeDirectory
# Expected: /home/mi-skam

nix eval --raw .#homeConfigurations."plumps@xbook".config.home.homeDirectory
# Expected: /Users/plumps
```

**Integration Tests:**
- Deploy to xmsi (Linux) and verify home directory
- Deploy to xbook (Darwin) and verify home directory

#### Rollback Plan

**Simple git revert:**
```bash
git checkout modules/home/*.nix
git rm modules/lib/platform.nix
```

#### Success Metrics

- [ ] `modules/lib/platform.nix` created
- [ ] 6 modules refactored to use platform library
- [ ] All home configurations build without errors
- [ ] 18 lines of duplication eliminated
- [ ] Platform detection works correctly on Darwin and Linux

---

### 2.5-2.7 Additional Nix Consolidations (Summary)

**For brevity, the following consolidations are summarized. Full procedures follow the same pattern as above.**

#### 2.5 Standardize SOPS Secrets Pattern
- **Priority Score:** 50
- **Impact:** 20 lines (conceptual)
- **Effort:** 2-3 hours
- **Scope:** Document standard pattern, consider helper function
- **Iteration:** I3.T6

#### 2.6 Standardize HM User Config Structure
- **Priority Score:** 30
- **Impact:** 30 lines
- **Effort:** 1-2 hours
- **Scope:** Create template/function for user configs
- **Iteration:** I3.T6

#### 2.7 Extract Timezone and Shell Config
- **Priority Score:** 25 (timezone), 20 (shell)
- **Impact:** 3 + 4 = 7 lines
- **Effort:** 0.5 hours each
- **Scope:** Already included in system-common.nix (§2.2)
- **Iteration:** I3.T2 (already covered)

---

## 3. Ansible Role Consolidations

### 3.1 Consolidation A1: Extract Bootstrap Tasks to Roles (CRITICAL PATH)

**Priority Score:** 375 (Impact: 75 lines, Risk: MEDIUM)
**Iteration:** I3.T3
**Effort:** 20-25 hours
**Dependencies:** None

#### Current State

**Problem:** `ansible/playbooks/bootstrap.yaml` contains 96 lines, of which ~75 lines should be in dedicated roles. This violates Ansible best practices and prevents role reuse.

**Affected Files:**
- `ansible/playbooks/bootstrap.yaml` (lines 22-89 contain role-worthy tasks)

**Tasks to Extract:**

**Lines 22-45: Package Installation (23 lines)**
```yaml
- name: Install common packages (Debian/Ubuntu)
  ansible.builtin.apt:
    name:
      - vim
      - htop
      - curl
      - wget
      - git
      - tmux
      - jq
    state: present
  when: ansible_os_family == "Debian"

- name: Install common packages (RedHat/Rocky)
  ansible.builtin.dnf:
    name:
      - vim
      - htop
      - curl
      - wget
      - git
      - tmux
      - jq
    state: present
  when: ansible_os_family == "RedHat"
```

**Lines 51-68: SSH Hardening (18 lines)**
```yaml
- name: Ensure .ssh directory exists
  ansible.builtin.file:
    path: /root/.ssh
    state: directory
    mode: '0700'
    owner: root
    group: root

- name: Configure SSH daemon
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
    validate: 'sshd -t -f %s'
  loop:
    - { regexp: '^#?PasswordAuthentication', line: 'PasswordAuthentication {{ ssh_password_authentication }}' }
    - { regexp: '^#?PermitRootLogin', line: 'PermitRootLogin {{ ssh_permit_root_login }}' }
  notify: Restart SSH
```

**Lines 70-89: Security Baseline (20 lines)**
```yaml
- name: Install unattended-upgrades (Debian/Ubuntu)
  ansible.builtin.apt:
    name: unattended-upgrades
    state: present
    update_cache: yes
  when:
    - ansible_os_family == "Debian"
    - unattended_upgrades_enabled | default(true)

- name: Setup automatic updates (RedHat/Rocky)
  when: ansible_os_family == "RedHat"
  block:
    - name: Install dnf-automatic
      ansible.builtin.dnf:
        name: dnf-automatic
        state: present
    - name: Enable and start dnf-automatic timer
      ansible.builtin.systemd:
        name: dnf-automatic.timer
        enabled: yes
        state: started
```

**Lines 91-95: Handler (5 lines)**
```yaml
handlers:
  - name: Restart SSH
    ansible.builtin.systemd:
      name: "{{ 'sshd' if ansible_os_family == 'RedHat' else 'ssh' }}"
      state: restarted
```

**Total Lines to Extract:** 23 + 18 + 20 + 5 = 66 lines

#### Proposed Changes

**Create Three New Roles:**

1. **Enhanced common role** (absorb package installation)
2. **New ssh-hardening role** (SSH configuration)
3. **New security-baseline role** (auto-updates)

**1. Enhanced Common Role**

**Create:** `ansible/roles/common/defaults/main.yaml`
```yaml
---
# Common role default variables

# Package management
common_packages:
  - vim
  - htop
  - curl
  - wget
  - git
  - tmux
  - jq

common_additional_packages: []
common_update_cache: true
common_upgrade_packages: false
common_upgrade_dist: false

# Filesystem
common_scripts_dir: /opt/scripts
common_log_dir: /var/log/homelab
common_directory_mode: '0755'

# Bash configuration
bash_aliases_path: /root/.bash_aliases
bash_aliases_owner: root
bash_aliases_group: root
bash_aliases_mode: '0644'
custom_bash_aliases: []
```

**Update:** `ansible/roles/common/tasks/main.yaml` (add package installation)
```yaml
---
# Common system configuration

- name: Update package cache
  ansible.builtin.apt:
    update_cache: yes
  when:
    - ansible_os_family == "Debian"
    - common_update_cache | default(true)
  tags: ['common', 'packages', 'cache']

- name: Update package cache (RedHat/Rocky)
  ansible.builtin.dnf:
    update_cache: yes
  when:
    - ansible_os_family == "RedHat"
    - common_update_cache | default(true)
  tags: ['common', 'packages', 'cache']

- name: Install common packages
  ansible.builtin.package:
    name: "{{ common_packages + common_additional_packages }}"
    state: present
  tags: ['common', 'packages', 'install']

- name: Create common directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: "{{ common_directory_mode }}"
  loop:
    - "{{ common_scripts_dir }}"
    - "{{ common_log_dir }}"
  tags: ['common', 'filesystem']

- name: Set up bash aliases
  ansible.builtin.template:
    src: bash_aliases.j2
    dest: "{{ bash_aliases_path }}"
    owner: "{{ bash_aliases_owner }}"
    group: "{{ bash_aliases_group }}"
    mode: "{{ bash_aliases_mode }}"
  tags: ['common', 'bash']
```

**Create:** `ansible/roles/common/templates/bash_aliases.j2`
```bash
# Homelab bash aliases - managed by Ansible
# Last updated: {{ ansible_date_time.iso8601 }}

# Common aliases
alias ll='ls -lah'
alias disk='df -h'
alias logs='tail -f {{ common_log_dir }}/*.log'

# OS-specific update aliases
{% if ansible_os_family == "Debian" %}
alias update-system='apt update && apt upgrade -y'
alias search-package='apt search'
{% elif ansible_os_family == "RedHat" %}
alias update-system='dnf update -y'
alias search-package='dnf search'
{% endif %}

# Custom aliases from group_vars
{% for alias in custom_bash_aliases | default([]) %}
alias {{ alias.name }}='{{ alias.command }}'
{% endfor %}
```

**2. New SSH Hardening Role**

**Create role structure:**
```bash
mkdir -p ansible/roles/ssh-hardening/{tasks,handlers,defaults,meta}
```

**Create:** `ansible/roles/ssh-hardening/defaults/main.yaml`
```yaml
---
# SSH hardening default variables

ssh_config_path: /etc/ssh/sshd_config
ssh_password_authentication: "no"
ssh_permit_root_login: "prohibit-password"
ssh_service_name_debian: ssh
ssh_service_name_redhat: sshd
ssh_config_backup: true
ssh_validate_config: true
ssh_root_ssh_dir: /root/.ssh
```

**Create:** `ansible/roles/ssh-hardening/tasks/main.yaml`
```yaml
---
# SSH hardening tasks

- name: Ensure .ssh directory exists
  ansible.builtin.file:
    path: "{{ ssh_root_ssh_dir }}"
    state: directory
    mode: '0700'
    owner: root
    group: root
  tags: ['ssh-hardening', 'ssh', 'filesystem']

- name: Configure SSH daemon
  ansible.builtin.lineinfile:
    path: "{{ ssh_config_path }}"
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
    validate: "{% if ssh_validate_config %}sshd -t -f %s{% endif %}"
    backup: "{{ ssh_config_backup }}"
  loop:
    - { regexp: '^#?PasswordAuthentication', line: 'PasswordAuthentication {{ ssh_password_authentication }}' }
    - { regexp: '^#?PermitRootLogin', line: 'PermitRootLogin {{ ssh_permit_root_login }}' }
  notify: Restart SSH
  tags: ['ssh-hardening', 'ssh', 'security']
```

**Create:** `ansible/roles/ssh-hardening/handlers/main.yaml`
```yaml
---
# SSH hardening handlers

- name: Restart SSH
  ansible.builtin.systemd:
    name: "{{ ssh_service_name_redhat if ansible_os_family == 'RedHat' else ssh_service_name_debian }}"
    state: restarted
  tags: ['ssh-hardening', 'ssh']
```

**Create:** `ansible/roles/ssh-hardening/meta/main.yaml`
```yaml
---
galaxy_info:
  role_name: ssh-hardening
  author: mi-skam
  description: SSH daemon security hardening for production servers
  license: MIT
  min_ansible_version: "2.12"
  platforms:
    - name: Debian
      versions:
        - bullseye
        - bookworm
    - name: EL
      versions:
        - 8
        - 9
    - name: Ubuntu
      versions:
        - focal
        - jammy
        - noble
  galaxy_tags:
    - ssh
    - security
    - hardening
    - baseline

dependencies: []
```

**3. New Security Baseline Role**

**Create role structure:**
```bash
mkdir -p ansible/roles/security-baseline/{tasks,defaults,meta}
```

**Create:** `ansible/roles/security-baseline/defaults/main.yaml`
```yaml
---
# Security baseline default variables

security_unattended_upgrades_enabled: true
security_automatic_reboot: false
security_automatic_reboot_time: "03:00"
security_dnf_automatic_apply_updates: true
```

**Create:** `ansible/roles/security-baseline/tasks/main.yaml`
```yaml
---
# Security baseline tasks

- name: Install unattended-upgrades (Debian/Ubuntu)
  ansible.builtin.apt:
    name: unattended-upgrades
    state: present
    update_cache: yes
  when:
    - ansible_os_family == "Debian"
    - security_unattended_upgrades_enabled | default(true)
  tags: ['security-baseline', 'security', 'auto-updates']

- name: Setup automatic updates (RedHat/Rocky)
  when:
    - ansible_os_family == "RedHat"
    - security_unattended_upgrades_enabled | default(true)
  tags: ['security-baseline', 'security', 'auto-updates']
  block:
    - name: Install dnf-automatic
      ansible.builtin.dnf:
        name: dnf-automatic
        state: present

    - name: Enable and start dnf-automatic timer
      ansible.builtin.systemd:
        name: dnf-automatic.timer
        enabled: yes
        state: started
```

**Create:** `ansible/roles/security-baseline/meta/main.yaml`
```yaml
---
galaxy_info:
  role_name: security-baseline
  author: mi-skam
  description: Security baseline with automatic updates for production servers
  license: MIT
  min_ansible_version: "2.12"
  platforms:
    - name: Debian
      versions:
        - bullseye
        - bookworm
    - name: EL
      versions:
        - 8
        - 9
    - name: Ubuntu
      versions:
        - focal
        - jammy
        - noble
  galaxy_tags:
    - security
    - baseline
    - auto-updates
    - compliance

dependencies: []
```

**4. Refactored Bootstrap Playbook**

**After refactoring:** `ansible/playbooks/bootstrap.yaml` (96 → ~25 lines)
```yaml
---
- name: Bootstrap new servers
  hosts: all
  become: true

  roles:
    - ssh-hardening
    - security-baseline
    - common

  tasks:
    - name: Set timezone
      community.general.timezone:
        name: "{{ timezone }}"
      tags: ['bootstrap', 'system']
```

**Lines After Refactoring:**
- `bootstrap.yaml`: 96 → 25 lines (saved 71)
- New files created: ~250 lines (roles + documentation)
- Net change: +179 lines (but massively improved structure)

#### Step-by-Step Migration Procedure

**Step 1: Create New Role Structures** (2 hours)
```bash
cd ansible/roles

# Create ssh-hardening role
mkdir -p ssh-hardening/{tasks,handlers,defaults,meta}
touch ssh-hardening/{tasks,handlers,defaults,meta}/main.yaml

# Create security-baseline role
mkdir -p security-baseline/{tasks,defaults,meta}
touch security-baseline/{tasks,defaults,meta}/main.yaml

# Create common role missing files
touch common/defaults/main.yaml
mkdir -p common/templates
touch common/templates/bash_aliases.j2

git add ssh-hardening/ security-baseline/ common/defaults/ common/templates/
```

**Step 2: Populate Role Files** (4 hours)
1. Copy content from "Proposed Changes" above into each file
2. Verify syntax:
   ```bash
   ansible-playbook --syntax-check playbooks/bootstrap.yaml
   ```
3. Stage all files:
   ```bash
   git add roles/*/
   ```

**Step 3: Update Bootstrap Playbook** (1 hour)
1. Backup original:
   ```bash
   cp playbooks/bootstrap.yaml playbooks/bootstrap.yaml.backup
   ```
2. Replace content with refactored version from above
3. Stage:
   ```bash
   git add playbooks/bootstrap.yaml
   ```

**Step 4: Test in Check Mode** (2 hours)
```bash
# Test against dev environment first
ansible-playbook playbooks/bootstrap.yaml --limit dev --check --diff

# Review output carefully - should show same changes as before refactoring
```

**Step 5: Deploy to Test Server** (3 hours)
```bash
# Deploy to test-1.dev.nbg
ansible-playbook playbooks/bootstrap.yaml --limit test-1.dev.nbg

# Verify services:
# - SSH configuration updated
# - Automatic updates enabled
# - Common packages installed
# - Directories created
```

**Step 6: Validate Test Server** (2 hours)
```bash
# SSH to test-1.dev.nbg
ssh root@test-1.dev.nbg

# Verify SSH config
grep PasswordAuthentication /etc/ssh/sshd_config
grep PermitRootLogin /etc/ssh/sshd_config

# Verify auto-updates
systemctl status unattended-upgrades  # Debian/Ubuntu
systemctl status dnf-automatic.timer  # Rocky

# Verify packages
which vim htop curl wget git tmux jq

# Verify directories
ls -ld /opt/scripts /var/log/homelab

# Verify bash aliases
cat /root/.bash_aliases
source /root/.bash_aliases
ll  # Should work
```

**Step 7: Deploy to Production (if test succeeds)** (3 hours)
```bash
# Deploy to production servers one by one
ansible-playbook playbooks/bootstrap.yaml --limit mail-1.prod.nbg
# Validate mail-1

ansible-playbook playbooks/bootstrap.yaml --limit syncthing-1.prod.hel
# Validate syncthing-1
```

**Step 8: Update Documentation** (3 hours)
- Create README.md for each new role (see §3.2 for templates)
- Update CLAUDE.md with new role information
- Document bootstrap procedure

#### Testing Approach

**Pre-Deployment Testing:**
```bash
# Syntax check
ansible-playbook --syntax-check playbooks/bootstrap.yaml

# Lint check
ansible-lint playbooks/bootstrap.yaml

# List tasks (verify correct order)
ansible-playbook playbooks/bootstrap.yaml --list-tasks

# Check mode (dry run)
ansible-playbook playbooks/bootstrap.yaml --limit dev --check --diff
```

**Post-Deployment Testing:**

**SSH Hardening Validation:**
```bash
# From control machine
ssh -o PasswordAuthentication=yes root@test-1.dev.nbg
# Should fail with "Permission denied" (good)

ssh -i ~/.ssh/id_rsa root@test-1.dev.nbg
# Should succeed with key (good)

# On server
sshd -T | grep passwordauthentication
# Expected: passwordauthentication no (prod), yes (dev)

sshd -T | grep permitrootlogin
# Expected: permitrootlogin prohibit-password (prod), yes (dev)
```

**Security Baseline Validation:**
```bash
# Debian/Ubuntu
systemctl status unattended-upgrades
apt-config dump APT::Periodic::Unattended-Upgrade
# Expected: "1"

# Rocky Linux
systemctl status dnf-automatic.timer
dnf automatic status
# Expected: timer active and enabled
```

**Common Role Validation:**
```bash
# Packages
dpkg -l | grep -E 'vim|htop|curl|wget|git|tmux|jq'  # Debian
rpm -qa | grep -E 'vim|htop|curl|wget|git|tmux|jq'  # Rocky
# Expected: all installed

# Directories
stat /opt/scripts
stat /var/log/homelab
# Expected: both exist with mode 0755

# Bash aliases
source /root/.bash_aliases
ll
update-system --help
# Expected: aliases work
```

**Integration Testing:**
```bash
# Run bootstrap again (test idempotency)
ansible-playbook playbooks/bootstrap.yaml --limit test-1.dev.nbg

# Output should show:
# - ok=X
# - changed=0 (if truly idempotent)
# - unreachable=0
# - failed=0
```

#### Rollback Plan

**If extraction fails:**

1. **Restore original bootstrap playbook:**
   ```bash
   mv playbooks/bootstrap.yaml.backup playbooks/bootstrap.yaml
   ```

2. **Remove new roles:**
   ```bash
   git rm -r roles/ssh-hardening
   git rm -r roles/security-baseline
   git checkout roles/common/
   ```

3. **Redeploy original bootstrap:**
   ```bash
   ansible-playbook playbooks/bootstrap.yaml --limit test-1.dev.nbg
   ```

**If test server breaks:**

1. **Destroy and recreate test server:**
   ```bash
   cd terraform/
   tofu destroy -target=hcloud_server.test-1
   tofu apply -target=hcloud_server.test-1
   ```

2. **Re-bootstrap with original playbook:**
   ```bash
   ansible-playbook playbooks/bootstrap.yaml.backup --limit test-1.dev.nbg
   ```

**Rollback triggers:**
- SSH access lost (cannot login)
- Automatic updates fail to install
- Common packages missing
- Services fail to start
- Idempotency test shows unexpected changes

#### Success Metrics

- [ ] 3 new roles created (ssh-hardening, security-baseline, common enhanced)
- [ ] All roles have complete file structure (tasks/, defaults/, meta/)
- [ ] Bootstrap playbook reduced from 96 to ≤30 lines
- [ ] ansible-playbook --syntax-check passes
- [ ] ansible-lint returns zero warnings
- [ ] Check mode shows expected changes
- [ ] Test server deployment succeeds
- [ ] All validation tests pass
- [ ] Idempotency test shows changed=0
- [ ] Production servers deploy successfully
- [ ] 75 lines of playbook logic moved to roles
- [ ] Roles are independently reusable

---

### 3.2 Consolidation A2: Add Galaxy Structure to All Roles (HIGH VALUE)

**Priority Score:** 150 (Impact: quality improvement, Risk: MEDIUM)
**Iteration:** I3.T4
**Effort:** 15-20 hours
**Dependencies:** Consolidation A1 (role extraction must be complete)

#### Current State

**Problem:** 0% of roles have complete Ansible Galaxy structure. This prevents publishing to Galaxy, reduces discoverability, and makes roles harder to use.

**Galaxy Structure Requirements:**

| Component | Purpose | Currently Missing |
|-----------|---------|-------------------|
| `meta/main.yaml` | Role metadata, dependencies, platforms | 3/3 roles (100%) |
| `defaults/main.yaml` | Default variable values | 2/3 roles (67%) |
| `README.md` | Usage documentation | 3/3 roles (100%) |
| `handlers/main.yaml` | Service restart handlers | 2/3 roles (67%) |

**Affected Roles:**
1. common (30% complete)
2. monitoring (5% complete - skeleton only)
3. storagebox (60% complete)
4. ssh-hardening (created in A1, needs README)
5. security-baseline (created in A1, needs README)

#### Proposed Changes

**For each role, add:**

1. **meta/main.yaml** - Galaxy metadata
2. **README.md** - Comprehensive documentation (100+ lines)
3. **defaults/main.yaml** (if missing)
4. **handlers/main.yaml** (if missing)

**Example README.md Template** (for storagebox role):

```markdown
# Ansible Role: storagebox

Mounts Hetzner Storage Box via CIFS/SMB protocol with persistent configuration.

## Requirements

- Ansible >= 2.12
- Target system must be Debian/Ubuntu or RedHat/Rocky Linux
- Valid Hetzner Storage Box credentials
- Network connectivity to Hetzner Storage Box

## Role Variables

### Required Variables

These variables MUST be defined in your inventory or playbook:

```yaml
storagebox_username: "u123456"           # Hetzner Storage Box username
storagebox_password: "your_password"     # Storage Box password (use Ansible Vault!)
storagebox_host: "u123456.your-storagebox.de"  # Storage Box hostname
```

### Optional Variables

Defined in `defaults/main.yaml` with sensible defaults:

```yaml
storagebox_mount_point: /mnt/storagebox  # Where to mount the storage box
storagebox_credentials_file: /root/.storagebox-credentials  # Credentials file location
storagebox_uid: 1000                      # UID for file ownership
storagebox_gid: 1000                      # GID for file ownership
```

## Dependencies

- `common` role (provides base system configuration)

## Example Playbook

```yaml
---
- name: Setup Storage Box mounting
  hosts: servers
  become: true

  vars:
    storagebox_username: "u123456"
    storagebox_password: "{{ vault_storagebox_password }}"  # From Ansible Vault
    storagebox_host: "u123456.your-storagebox.de"

  roles:
    - common
    - storagebox
```

### Using with SOPS Encrypted Secrets

```yaml
---
- name: Setup Storage Box with SOPS
  hosts: all
  become: true

  tasks:
    - name: Load SOPS encrypted secrets
      community.sops.load_vars:
        file: ../../secrets/storagebox.yaml
      delegate_to: localhost

    - name: Set storagebox variables
      ansible.builtin.set_fact:
        storagebox_username: "{{ storagebox.username }}"
        storagebox_password: "{{ storagebox.password }}"
        storagebox_host: "{{ storagebox.host }}"

    - name: Include storagebox role
      ansible.builtin.include_role:
        name: storagebox
```

## Idempotency

This role is fully idempotent:
- Mount configuration is managed by `ansible.posix.mount` (idempotent by design)
- Credentials file uses `template` module (only changes when content differs)
- Package installation via `package` module (idempotent)

## Security Considerations

**CRITICAL:** Never commit Storage Box credentials to version control!

Use one of these methods:
1. **Ansible Vault:** Encrypt credentials with `ansible-vault`
2. **SOPS:** Use SOPS with age encryption (project standard)
3. **Environment Variables:** Pass via `--extra-vars`

Credentials file (`/root/.storagebox-credentials`) is created with mode `0600` (root only).

## Troubleshooting

### Mount fails with "Permission denied"
- Verify credentials are correct
- Check network connectivity to Storage Box
- Ensure `cifs-utils` is installed: `dpkg -l | grep cifs-utils`

### Mount point shows wrong permissions
- Adjust `storagebox_uid` and `storagebox_gid` in your variables
- Current mount options use `file_mode=0777,dir_mode=0777` (consider restricting)

### Changes not applied
- Run with `-vvv` flag for debug output
- Check `/var/log/syslog` for mount errors
- Verify Storage Box is not in maintenance mode

## Tags

This role supports the following tags:
- `storagebox` - All tasks in this role
- `storage` - Storage-related tasks
- `mount` - Mounting tasks only

Example: `ansible-playbook playbook.yaml --tags storagebox`

## License

MIT

## Author Information

Created by mi-skam for homelab infrastructure management.

Repository: https://github.com/mi-skam/infra
```

#### Step-by-Step Migration Procedure

**Step 1: Create meta/main.yaml for All Roles** (3 hours)
```bash
cd ansible/roles

# For each role: common, monitoring, storagebox, ssh-hardening, security-baseline
touch common/meta/main.yaml
touch monitoring/meta/main.yaml
touch storagebox/meta/main.yaml
# (ssh-hardening and security-baseline already have meta/main.yaml from A1)

# Populate with Galaxy metadata (use templates from Consolidation A1)
```

**Step 2: Create README.md for All Roles** (10 hours - 2 hours per role)
```bash
# For each role
touch common/README.md
touch monitoring/README.md
touch storagebox/README.md
touch ssh-hardening/README.md
touch security-baseline/README.md

# Write comprehensive documentation (use template above)
# Aim for 100-150 lines per README
```

**Step 3: Fill Missing defaults/main.yaml** (2 hours)
```bash
# monitoring role needs defaults
touch monitoring/defaults/main.yaml

# Populate with sensible defaults
```

**Step 4: Validate Galaxy Structure** (2 hours)
```bash
# Use ansible-galaxy to validate structure
cd ansible/roles
for role in common monitoring storagebox ssh-hardening security-baseline; do
  ansible-galaxy role init --init-path=/tmp $role --offline
  # Compare structure with project roles
  diff -r /tmp/$role $role
done
```

**Step 5: Lint and Document** (3 hours)
```bash
# Run ansible-lint on all roles
ansible-lint roles/*/

# Fix any warnings
# Update CLAUDE.md with role documentation
```

#### Testing Approach

**Structure Validation:**
```bash
# Each role should have:
for role in common monitoring storagebox ssh-hardening security-baseline; do
  echo "Checking $role..."
  test -f roles/$role/meta/main.yaml && echo "  ✓ meta/main.yaml" || echo "  ✗ meta/main.yaml"
  test -f roles/$role/defaults/main.yaml && echo "  ✓ defaults/main.yaml" || echo "  ✗ defaults/main.yaml"
  test -f roles/$role/README.md && echo "  ✓ README.md" || echo "  ✗ README.md"
  test -f roles/$role/tasks/main.yaml && echo "  ✓ tasks/main.yaml" || echo "  ✗ tasks/main.yaml"
done
```

**Documentation Quality:**
```bash
# Check README length (should be >= 100 lines)
wc -l roles/*/README.md

# Check for required sections
for readme in roles/*/README.md; do
  echo "Checking $readme..."
  grep -q "## Requirements" $readme && echo "  ✓ Requirements" || echo "  ✗ Requirements"
  grep -q "## Role Variables" $readme && echo "  ✓ Variables" || echo "  ✗ Variables"
  grep -q "## Example Playbook" $readme && echo "  ✓ Example" || echo "  ✗ Example"
  grep -q "## License" $readme && echo "  ✓ License" || echo "  ✗ License"
done
```

**Lint Validation:**
```bash
ansible-lint roles/*/
# Expected: zero warnings
```

#### Rollback Plan

**Simple git revert:**
```bash
git checkout roles/*/meta/main.yaml
git checkout roles/*/README.md
git checkout roles/*/defaults/main.yaml
```

**No functional changes**, so rollback is low-risk.

#### Success Metrics

- [ ] All 5 roles have `meta/main.yaml`
- [ ] All 5 roles have `defaults/main.yaml`
- [ ] All 5 roles have `README.md` (≥100 lines each)
- [ ] All READMEs contain required sections
- [ ] ansible-lint returns zero warnings
- [ ] 100% Galaxy structure completeness (up from 0%)
- [ ] Roles ready for Ansible Galaxy publication

---

### 3.3 Consolidation A3: Parameterize All Hardcoded Values (HIGH VALUE)

**Priority Score:** 90 (Impact: quality improvement, Risk: LOW)
**Iteration:** I3.T4
**Effort:** 5-7 hours
**Dependencies:** Consolidation A1 (role structure complete)

#### Current State

**Problem:** 8 hardcoded values across roles and playbooks prevent flexible configuration.

**Identified Hardcoded Values:**

| # | File | Line | Value | Recommended Variable | Priority |
|---|------|------|-------|---------------------|----------|
| 1 | common/tasks/main.yaml | 24 | `/opt/scripts` | `common_scripts_dir` | HIGH |
| 2 | common/tasks/main.yaml | 25 | `/var/log/homelab` | `common_log_dir` | HIGH |
| 3 | common/tasks/main.yaml | 29 | `/root/.bash_aliases` | `bash_aliases_path` | MEDIUM |
| 4 | common/tasks/main.yaml | 30-35 | Inline aliases | Use template | HIGH |
| 5 | bootstrap.yaml | 48 | `"Europe/Berlin"` | Use `timezone` variable | MEDIUM |
| 6 | bootstrap.yaml | 60 | `/etc/ssh/sshd_config` | `ssh_config_path` | LOW |
| 7 | mailcow-backup.yaml | 11 | `/opt/mailcow-dockerized` | `mailcow_install_dir` | HIGH |
| 8 | mailcow-backup.yaml | 12 | `/mnt/storagebox/mailcow` | `mailcow_backup_dir` | HIGH |

#### Proposed Changes

**1-4: Common Role** (already covered in Consolidation A1, §3.1)

**5: Bootstrap Timezone** (quick fix)

**Before:**
```yaml
# bootstrap.yaml:47-49
- name: Set timezone
  community.general.timezone:
    name: "Europe/Berlin"  # HARDCODED
```

**After:**
```yaml
# bootstrap.yaml:47-49
- name: Set timezone
  community.general.timezone:
    name: "{{ timezone }}"  # Uses group_vars/all.yaml
```

**6: SSH Config Path** (already in ssh-hardening role defaults)

**7-8: Mailcow Paths**

**Create:** `ansible/inventory/group_vars/prod.yaml` (add mailcow section)
```yaml
# Mail server configuration (mail-1.prod.nbg only)
mailcow_install_dir: /opt/mailcow-dockerized
mailcow_backup_dir: "{{ storagebox_mount_point }}/mailcow"
mailcow_backup_cron_hour: "2"
mailcow_backup_cron_minute: "0"
```

**Update:** `ansible/playbooks/mailcow-backup.yaml`
```yaml
---
- name: Backup mailcow to Storage Box
  hosts: mail-1.prod.nbg
  become: true

  tasks:
    - name: Check if mailcow is installed
      ansible.builtin.stat:
        path: "{{ mailcow_install_dir }}"
      register: mailcow_dir_stat

    - name: Fail if mailcow not found
      ansible.builtin.fail:
        msg: "Mailcow installation directory {{ mailcow_install_dir }} not found"
      when: not mailcow_dir_stat.stat.exists

    - name: Ensure backup directory exists
      ansible.builtin.file:
        path: "{{ mailcow_backup_dir }}"
        state: directory
        mode: '0755'

    - name: Run mailcow backup
      ansible.builtin.shell: |
        cd {{ mailcow_install_dir }}
        MAILCOW_BACKUP_LOCATION={{ mailcow_backup_dir }} {{ mailcow_install_dir }}/helper-scripts/backup_and_restore.sh backup all
      args:
        executable: /bin/bash
      register: backup_result
      changed_when: backup_result.rc == 0

    - name: Display backup result
      ansible.builtin.debug:
        var: backup_result.stdout_lines
```

#### Step-by-Step Migration Procedure

**Step 1: Update Common Role** (2 hours)
- Already covered in A1 - defaults/main.yaml and templates/bash_aliases.j2

**Step 2: Fix Bootstrap Timezone** (15 minutes)
```bash
# Edit playbooks/bootstrap.yaml line 48
sed -i 's/name: "Europe\/Berlin"/name: "{{ timezone }}"/' playbooks/bootstrap.yaml

# Verify
grep timezone playbooks/bootstrap.yaml
```

**Step 3: Parameterize Mailcow** (2 hours)
```bash
# Add mailcow variables to group_vars/prod.yaml
vim inventory/group_vars/prod.yaml
# Add mailcow section from above

# Update mailcow-backup.yaml playbook
vim playbooks/mailcow-backup.yaml
# Replace hardcoded paths with variables

# Stage changes
git add inventory/group_vars/prod.yaml playbooks/mailcow-backup.yaml
```

**Step 4: Validation** (1 hour)
```bash
# Verify all variables defined
ansible-inventory --list --yaml | grep -E 'common_scripts_dir|mailcow_install_dir|timezone'

# Test bootstrap playbook
ansible-playbook playbooks/bootstrap.yaml --limit dev --check

# Test mailcow backup
ansible-playbook playbooks/mailcow-backup.yaml --limit mail-1.prod.nbg --check
```

#### Testing Approach

**Variable Substitution Test:**
```bash
# Verify variables resolve correctly
ansible -m debug -a "var=common_scripts_dir" all
ansible -m debug -a "var=mailcow_install_dir" mail-1.prod.nbg
ansible -m debug -a "var=timezone" all
```

**Playbook Dry Run:**
```bash
ansible-playbook playbooks/bootstrap.yaml --limit test-1.dev.nbg --check --diff
# Verify: timezone task shows {{ timezone }} value

ansible-playbook playbooks/mailcow-backup.yaml --limit mail-1.prod.nbg --check --diff
# Verify: paths use variables, not hardcoded values
```

**Integration Test:**
```bash
# Deploy to test server
ansible-playbook playbooks/bootstrap.yaml --limit test-1.dev.nbg

# Verify timezone
ssh root@test-1.dev.nbg "timedatectl"
# Expected: "Time zone: Europe/Berlin"

# Verify directories use variables
ssh root@test-1.dev.nbg "ls -ld /opt/scripts /var/log/homelab"
```

#### Rollback Plan

**Git revert affected files:**
```bash
git checkout playbooks/bootstrap.yaml
git checkout playbooks/mailcow-backup.yaml
git checkout inventory/group_vars/prod.yaml
```

**Low risk** - parameterization doesn't change functionality, only makes values configurable.

#### Success Metrics

- [ ] All 8 hardcoded values eliminated
- [ ] Variables defined in appropriate locations (defaults/ or group_vars/)
- [ ] grep -r '"/opt\|"/var/log\|"/root\|"/etc' roles/ returns only comments
- [ ] All playbooks pass --check mode
- [ ] Test deployment succeeds with parameterized values
- [ ] Documentation updated to explain variables

---

### 3.4 Consolidation A4: Implement Monitoring Role (DEFERRED TO I5+)

**Priority Score:** 35 (Impact: new functionality, Risk: HIGH)
**Iteration:** I5+ (post-refactoring)
**Effort:** 8-10 hours
**Dependencies:** All I3 consolidations complete

**Note:** Monitoring role implementation is deferred to Iteration 5+ as it addresses operational gaps (Gap 5.1 from baseline report) rather than refactoring existing code. This consolidation is documented for completeness but not required for I3 completion.

**Scope:**
- Implement complete monitoring role (currently skeleton)
- Install Prometheus node_exporter
- Configure log forwarding
- Add health check endpoints

**See:** Baseline Report §5.1 for detailed requirements.

---

## 4. Implementation Timeline

### 4.1 Gantt-Style Timeline

**Iteration 3 Duration:** 2-3 weeks (48-65 hours total effort)

```
Week 1: Critical Path Consolidations
├─ Mon-Tue: N1 (User Account Builder) - 3 hours
├─ Tue-Wed: N2 (System Common Library) - 2 hours
├─ Wed-Fri: A1 (Extract Bootstrap to Roles) - 25 hours
└─ Fri: Testing and validation

Week 2: High-Value Consolidations
├─ Mon-Tue: A2 (Add Galaxy Structure) - 20 hours
├─ Wed: A3 (Parameterize Hardcoded Values) - 7 hours
├─ Thu: N3 (Extract HM Config Helpers) - 6 hours
└─ Fri: Integration testing

Week 3: Polish and Quality
├─ Mon: N4 (Platform Utility) - 1 hour
├─ Tue: N5-N7 (Remaining Nix consolidations) - 4 hours
├─ Wed-Thu: Documentation, README updates - 8 hours
├─ Fri: Final validation, commit, tag release
└─ Buffer: +2 days for issues/revisions
```

### 4.2 Task Breakdown by Iteration Task

**I3.T1:** This document (consolidation plan) - COMPLETE

**I3.T2:** Critical Nix consolidations (HIGH priority)
- N1: Create User Account Builder (3 hours)
- N2: Create System Common Library (2 hours)
- Total: 5 hours

**I3.T3:** Critical Ansible consolidations (HIGH priority)
- A1: Extract Bootstrap Tasks to Roles (25 hours)
- Total: 25 hours

**I3.T4:** Ansible quality improvements
- A2: Add Galaxy Structure (20 hours)
- A3: Parameterize Hardcoded Values (7 hours)
- Total: 27 hours

**I3.T5:** Additional Nix consolidations
- N3: Extract HM Config Helpers (6 hours)
- N4: Create Platform Utility (1 hour)
- Total: 7 hours

**I3.T6:** Final polish and documentation
- N5-N7: Remaining Nix consolidations (4 hours)
- Documentation updates (8 hours)
- Final validation (4 hours)
- Total: 16 hours

**Grand Total:** 80 hours estimated, 65 hours realistic (with parallelization)

### 4.3 Dependency Graph

```
I3.T1 (Plan)
    |
    ├──> I3.T2 (Nix Critical) ──┐
    |                           |
    └──> I3.T3 (Ansible Critical) ──> I3.T4 (Ansible Quality)
                                |                 |
    I3.T5 (Nix Additional) <────┘                 |
            |                                     |
            └─────────────────> I3.T6 (Polish) <─┘
```

**Critical Path:** I3.T1 → I3.T3 → I3.T4 → I3.T6 (57 hours)
**Parallel Path:** I3.T2 → I3.T5 (can run concurrently with I3.T3-T4)

### 4.4 Resource Allocation

**Solo developer workflow:**
- Focus on critical path first (I3.T3: Ansible extraction is highest risk)
- Nix consolidations can be done in parallel during waiting periods
- Documentation can be written incrementally

**Recommended order:**
1. Day 1-2: I3.T2 (Nix critical) - quick wins, build confidence
2. Day 3-7: I3.T3 (Ansible extraction) - highest risk, needs focus
3. Day 8-10: I3.T4 (Ansible quality) - builds on T3 success
4. Day 11-12: I3.T5 (Nix additional) - medium complexity
5. Day 13-15: I3.T6 (Polish) - low risk, high satisfaction

---

## 5. Risk Assessment and Mitigation

### 5.1 Risk Matrix

| Risk | Probability | Impact | Severity | Mitigation |
|------|-------------|--------|----------|------------|
| **User account creation breaks** | LOW | HIGH | MEDIUM | Rollback via NixOS generations, test in VM first |
| **SSH lockout during hardening** | MEDIUM | CRITICAL | HIGH | Always test on dev server first, keep console access |
| **Ansible playbook syntax errors** | LOW | MEDIUM | LOW | Use --syntax-check and --check mode |
| **Platform detection breaks cross-platform builds** | LOW | MEDIUM | LOW | Test Darwin and NixOS separately |
| **Bootstrap extraction introduces regression** | MEDIUM | MEDIUM | MEDIUM | Extensive check mode testing, deploy to dev first |
| **Galaxy structure incomplete** | LOW | LOW | LOW | Use ansible-galaxy init as reference |
| **Documentation quality insufficient** | MEDIUM | LOW | LOW | Peer review, use template |
| **Timeline overrun** | HIGH | MEDIUM | MEDIUM | Built-in 20% buffer, prioritize critical path |

### 5.2 SSH Lockout Prevention (CRITICAL)

**Risk:** Ansible ssh-hardening role misconfigures SSH, locking out access.

**Mitigation Steps:**

1. **Always test on dev server first:**
   ```bash
   ansible-playbook playbooks/bootstrap.yaml --limit test-1.dev.nbg
   ```

2. **Keep Hetzner console access open:**
   - Before deployment, open Hetzner Cloud Console for server
   - If SSH fails, use web console to fix `/etc/ssh/sshd_config`

3. **Use check mode first:**
   ```bash
   ansible-playbook playbooks/bootstrap.yaml --limit mail-1.prod.nbg --check --diff
   # Review SSH config changes before applying
   ```

4. **Test SSH immediately after deployment:**
   ```bash
   ansible-playbook playbooks/bootstrap.yaml --limit mail-1.prod.nbg
   # Immediately test
   ssh root@mail-1.prod.nbg "echo 'SSH works'"
   # If this fails, use console to rollback
   ```

5. **Rollback procedure if locked out:**
   ```bash
   # Via Hetzner console:
   cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
   systemctl restart ssh
   ```

### 5.3 Timeline Risk Mitigation

**Risk:** 65-hour estimate may overrun due to unforeseen issues.

**Mitigation:**

1. **Built-in buffer:** 80-hour estimate includes 20% buffer (15 hours)
2. **Prioritization:** Critical path items (T2, T3) completed first
3. **Incremental commits:** Commit after each consolidation (enables partial success)
4. **Defer low-priority items:** N5-N7 can be deferred to I4 if needed
5. **Weekend buffer:** 3-week timeline allows weekend overflow

### 5.4 Quality Risk Mitigation

**Risk:** Rushed consolidations introduce bugs or reduce code quality.

**Mitigation:**

1. **Test-driven approach:** Write tests before refactoring
2. **Pair review:** Review each consolidation against analysis documents
3. **Idempotency validation:** Run playbooks twice, verify changed=0
4. **Documentation requirement:** No consolidation complete without updated docs
5. **Lint enforcement:** ansible-lint and nix flake check must pass

---

## 6. Acceptance Criteria

### 6.1 Per-Consolidation Criteria

Each consolidation has specific success metrics (see individual sections §2.1-2.7, §3.1-3.4).

### 6.2 Overall Iteration 3 Acceptance Criteria

**MUST HAVE (Blocking I3 completion):**

- [ ] **Nix Module Consolidations:**
  - [ ] N1: User Account Builder created, 80 lines saved
  - [ ] N2: System Common Library created, 35 lines saved
  - [ ] All NixOS and Darwin configurations build without errors
  - [ ] Zero functional regressions (derivation outputs identical)

- [ ] **Ansible Role Consolidations:**
  - [ ] A1: Bootstrap playbook reduced to ≤30 lines
  - [ ] A1: ssh-hardening and security-baseline roles created
  - [ ] A1: All roles have complete file structure
  - [ ] A2: All 5 roles have 100% Galaxy structure
  - [ ] A2: All roles have README.md ≥100 lines
  - [ ] A3: Zero hardcoded values in roles/playbooks

- [ ] **Code Quality:**
  - [ ] ansible-lint returns zero warnings
  - [ ] nix flake check passes
  - [ ] All playbooks idempotent (changed=0 on second run)

- [ ] **Documentation:**
  - [ ] CLAUDE.md updated with new roles
  - [ ] All README.md files complete
  - [ ] Migration procedures documented

**SHOULD HAVE (High priority, complete if time allows):**

- [ ] **Additional Nix Consolidations:**
  - [ ] N3: HM Config Helpers extracted
  - [ ] N4: Platform Detection Utility created

- [ ] **Testing:**
  - [ ] All consolidations tested on dev server
  - [ ] At least 2 production deployments successful

**NICE TO HAVE (Defer to I4 if needed):**

- [ ] **Low-Priority Consolidations:**
  - [ ] N5-N7: SOPS pattern, HM user config, minor extractions

- [ ] **Quality Improvements:**
  - [ ] Molecule tests for Ansible roles
  - [ ] NixOS VM tests for configurations

### 6.3 Quantitative Success Metrics

**From Executive Summary (§0), expected deltas:**

| Metric | Baseline | Target | Achieved | Status |
|--------|----------|--------|----------|--------|
| **Nix Metrics** |
| Total Nix lines | 973 | ~730 | ___ | ⬜ |
| Duplication rate | 18% | <5% | ___% | ⬜ |
| Shared libraries | 0 | 4 | ___ | ⬜ |
| **Ansible Metrics** |
| Galaxy compliance | 0% | 100% | ___% | ⬜ |
| Bootstrap lines | 96 | ≤30 | ___ | ⬜ |
| Hardcoded values | 8 | 0 | ___ | ⬜ |
| Role documentation | 0/3 | 5/5 | ___/5 | ⬜ |
| **Overall** |
| Total consolidations | - | 12 | ___ | ⬜ |
| Lines saved | - | ~280 | ___ | ⬜ |

**Instructions:** Fill in "Achieved" column upon I3 completion. Status: ✅ (met target), ⚠️ (partial), ❌ (missed)

---

## 7. Conclusion

This consolidation plan provides detailed, actionable guidance for Iteration 3 refactoring. It synthesizes findings from three comprehensive analyses (Nix modules, Ansible roles, baseline report) into a prioritized roadmap with:

- **12 consolidations** identified and prioritized by impact/risk
- **80 hours** of estimated effort (65 hours realistic)
- **2-3 weeks** of calendar time
- **Step-by-step procedures** with rollback plans for each consolidation
- **Clear acceptance criteria** with quantitative targets

**Key Achievements Expected:**
- Reduce code duplication from 18% to <5%
- Achieve 100% Ansible Galaxy compliance (up from 0%)
- Save ~280 lines of code through consolidation
- Improve maintainability through shared libraries and proper role structure

**Critical Success Factors:**
1. **Follow the critical path:** I3.T2 → I3.T3 → I3.T4 → I3.T6
2. **Test extensively:** Use check mode, deploy to dev first, validate thoroughly
3. **Document incrementally:** Update docs as consolidations complete
4. **Rollback readiness:** Keep console access, maintain backups
5. **Quality over speed:** Prioritize correctness over timeline

**Next Steps:**
1. Begin I3.T2 (Nix critical consolidations) - lowest risk, quick wins
2. Commit this plan: `git add docs/refactoring/module_consolidation_plan.md`
3. Create tracking issue for I3 with checklist from §6.2
4. Execute consolidations following procedures in §2-3

This plan is **READY FOR EXECUTION**. All analysis complete, all procedures documented, all risks assessed.

---

**Document Status:** Final - Ready for Implementation
**Approval Required:** No (solo project)
**Next Review:** After I3.T6 completion (compare actual vs planned metrics)

**Version History:**
- v1.0 (2025-10-29): Initial consolidation plan based on three completed analyses
