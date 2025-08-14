# Docker Testing Plan - Machine Class Based

## 🎯 Overview

Redesign Docker testing to use realistic machine classes that validate both package management and configuration deployment. Focus on three tiers: essential, developer, and GUI.

## 📦 Test Tiers Strategy

### **Essential Tier**
- **Purpose**: Bare minimum system for basic shell work
- **Package Managers**: Single native PM only
- **Tests**: Bootstrap → Configure → Stow → Basic health check
- **Packages**: ~8-15 core system tools

### **Developer Tier** 
- **Purpose**: Full CLI development environment with multi-PM
- **Package Managers**: Native + pip + npm + modern Emacs source
- **Tests**: Essential + Package installation + Multi-PM validation + Emacs config
- **Packages**: ~50-80 development tools
- **Key Requirement**: **Emacs 30+** (LSP, tree-sitter, native compilation)

### **GUI Tier**
- **Purpose**: Desktop application validation (install only, no execution)
- **Package Managers**: Developer + desktop packages
- **Tests**: Developer + Desktop package validation + GUI config deployment
- **Packages**: ~100+ including desktop applications
- **Note**: No actual GUI execution in Docker (validation only)

## 🖥️ Platform Coverage

### **Ubuntu Variants**
```bash
just test-docker-ubuntu-essential   # apt-get only
just test-docker-ubuntu-developer   # apt-get + pip + npm + Emacs source
just test-docker-ubuntu-gui         # + desktop packages (validation)
```

### **Arch Variants**
```bash
just test-docker-arch-essential     # pacman only  
just test-docker-arch-developer     # pacman + AUR/yay + pip + npm + Emacs source
just test-docker-arch-gui           # + desktop packages (validation)
```

## 📋 Machine Class Structure

```
package-management/machines/
├── docker_test_ubuntu_essential/
│   └── apt/
│       └── packages.txt           # 8-15 core packages
├── docker_test_ubuntu_developer/
│   ├── apt/
│   │   └── packages.txt           # ~30-40 packages + build deps
│   ├── pip/
│   │   └── requirements.txt       # ~10-20 Python packages  
│   ├── npm/
│   │   └── packages.txt           # ~5-10 Node packages
│   └── emacs-source/              # Emacs 30+ build config
├── docker_test_ubuntu_gui/
│   ├── (developer packages) +
│   └── apt/
│       └── gui-packages.txt       # Desktop applications
├── docker_test_arch_essential/
│   └── pacman/
│       └── packages.txt           # 8-15 core packages
├── docker_test_arch_developer/
│   ├── pacman/
│   │   └── packages.txt           # ~20-30 packages
│   ├── aur/                       # AUR packages via yay
│   │   └── packages.txt
│   ├── pip/
│   │   └── requirements.txt
│   ├── npm/
│   │   └── packages.txt
│   └── emacs-source/              # Emacs 30+ build config
└── docker_test_arch_gui/
    ├── (developer packages) +
    └── pacman/
        └── gui-packages.txt       # Desktop applications
```

## 🔧 Technical Requirements

### **Package Manager Standards**
- **Ubuntu**: Use `apt-get` (not `apt`) for scripting stability
- **Arch**: Use `pacman` + `yay` for AUR packages
- **Cross-platform**: pip, npm consistently across both

### **Emacs 30+ Requirement**
- **Critical**: Must support LSP, tree-sitter, native compilation
- **Ubuntu**: Build from source or use modern PPA
- **Arch**: Build from source or use AUR package
- **Config Testing**: Validate Doom/Spacemacs configurations work

### **Docker Workflow Requirements**

#### **Staged Testing**
- **Multi-stage Dockerfiles**: Each stage validates specific workflow step
- **Stage Targets**: `configure`, `bootstrap`, `stow`, `install`, `validate`
- **Individual Testing**: Can test any stage independently
- **Sequential Validation**: Each stage builds on previous success

#### **End-User Command Fidelity**
- **Real Commands**: Use actual `just` commands users will run
- **Minimize Docker-specific hacks**: Avoid custom scripts for Docker
- **User Experience**: Commands should match real usage patterns
- **Configuration-driven**: Use environment variables for automation

#### **Non-Interactive Automation**
- **Environment Variable**: `DOTFILES_NON_INTERACTIVE=true` for automation
- **Timeout Elimination**: No waiting for user input in Docker
- **Default Selection**: Automatic selection of sensible defaults
- **Fast Execution**: Optimize for CI/testing speed

#### **Logging and Observability**
- **Centralized Logs**: All outputs go to `/home/user/dotfiles/logs/`
- **Persistent Logs**: Logs survive container execution
- **Structured Output**: Clear stage completion markers
- **Debugging**: Final image contains complete execution history

### **Docker Constraints**
- **No Nix**: Too heavy for Docker testing (except for Emacs if required)
- **No GUI Execution**: Install validation only
- **Focus**: Package management + configuration deployment
- **ARM64 Support**: Handle missing bottles gracefully

## 🧪 Staged Workflow Testing

### **Docker Stage Architecture**
Each machine class should have independent testable stages:

```dockerfile
# Stage 1: Configuration
FROM base AS docker_test_ubuntu_essential_configure
ENV DOTFILES_NON_INTERACTIVE=true
RUN ./configure.sh --defaults --machine-class=docker_test_ubuntu_essential

# Stage 2: Bootstrap  
FROM docker_test_ubuntu_essential_configure AS docker_test_ubuntu_essential_bootstrap
RUN ./bootstrap.sh

# Stage 3: Stow
FROM docker_test_ubuntu_essential_bootstrap AS docker_test_ubuntu_essential_stow  
RUN just stow

# Stage 4: Install
FROM docker_test_ubuntu_essential_stow AS docker_test_ubuntu_essential_install
RUN just install-packages

# Stage 5: Validate (Final)
FROM docker_test_ubuntu_essential_install AS docker_test_ubuntu_essential
RUN just check-health && \
    just show-package-stats && \
    echo "✅ docker_test_ubuntu_essential complete!"
```

### **Individual Stage Testing**
```bash
# Test specific stages
just test-docker-ubuntu-essential-configure
just test-docker-ubuntu-essential-bootstrap  
just test-docker-ubuntu-essential-stow
just test-docker-ubuntu-essential-install
just test-docker-ubuntu-essential           # Full workflow

# Test specific stages for debugging
just test-run-docker-ubuntu-essential-stow  # Interactive at stow stage
```

### **Complete Machine Class Tests**
```bash
just test-docker-ubuntu-essential
just test-docker-ubuntu-developer  
just test-docker-ubuntu-gui
just test-docker-arch-essential
just test-docker-arch-developer
just test-docker-arch-gui
```

### **Batch Tests**
```bash
just test-docker-ubuntu-all        # All Ubuntu tiers
just test-docker-arch-all          # All Arch tiers  
just test-docker-all               # Everything
```

### **Interactive Testing**
```bash
just test-run-docker-ubuntu-developer
just test-run-docker-arch-developer
```

## ✅ Validation Steps

### **Essential Tier**
1. Bootstrap system (install core tools)
2. Configure machine class
3. Deploy configurations (stow)
4. Basic health check (symlinks, tools)

### **Developer Tier**  
1. Essential tier validation
2. Multi-package manager installation
3. Emacs 30+ build and configuration
4. Development tool validation
5. Comprehensive health check

### **GUI Tier**
1. Developer tier validation
2. Desktop package installation
3. GUI configuration deployment
4. Complete system validation

## 🎯 Success Criteria

- **All tiers pass** on both Ubuntu and Arch
- **Emacs 30+ confirmed** with full feature set
- **Multi-PM coordination** works without conflicts
- **Configuration deployment** successful across all tiers
- **Health checks pass** with zero broken symlinks
- **Realistic validation** of actual user scenarios

## 📝 Implementation Requirements

### **Configuration Script Updates**
```bash
# configure.sh must support non-interactive mode
./configure.sh --defaults --machine-class=docker_test_ubuntu_essential
./configure.sh --non-interactive --platform=ubuntu --machine-class=docker_test_arch_essential

# Environment variable support
export DOTFILES_NON_INTERACTIVE=true
./configure.sh  # Should use defaults, no prompts
```

### **Just Command Updates**
Commands that prompt for user input need non-interactive modes:
```bash
# These commands must respect DOTFILES_NON_INTERACTIVE
just install-packages      # No prompts in Docker
just upgrade-packages      # No confirmation prompts  
just configure             # Use defaults
```

### **Logging Requirements**
```bash
# All scripts must log to standardized locations
/home/user/dotfiles/logs/configure-YYYYMMDD-HHMMSS.log
/home/user/dotfiles/logs/bootstrap-YYYYMMDD-HHMMSS.log  
/home/user/dotfiles/logs/stow-YYYYMMDD-HHMMSS.log
/home/user/dotfiles/logs/install-packages-YYYYMMDD-HHMMSS.log
/home/user/dotfiles/logs/health-check-YYYYMMDD-HHMMSS.log

# Docker logs should be accessible via:
docker run -it dotfiles-test-docker_test_ubuntu_essential bash
# Then: ls -la /home/user/dotfiles/logs/
```

### **Staged Dockerfile Structure**
```dockerfile
# Each stage should:
1. Use real user commands (./configure.sh, just bootstrap, etc.)
2. Set DOTFILES_NON_INTERACTIVE=true
3. Log all operations
4. Validate stage completion
5. Allow independent testing
```

### **Implementation Steps**
1. **Add non-interactive support** to configure.sh and just commands
2. **Create staged Dockerfiles** with proper stage targets
3. **Update test justfile** with stage-specific commands
4. **Create missing machine classes** (arch variants)
5. **Add Emacs build configurations** for developer tier
6. **Validate complete workflow** on both platforms
7. **Test log accessibility** from final containers

### **Success Criteria**
- ✅ Each stage can be tested independently
- ✅ Final container has complete logs in `/home/user/dotfiles/logs/`  
- ✅ Commands match real user experience
- ✅ No interactive prompts in Docker
- ✅ All three tiers work on both Ubuntu and Arch
- ✅ Logs provide clear debugging information

This plan ensures Docker testing provides realistic validation of user workflows while maintaining debugging capabilities through comprehensive logging.