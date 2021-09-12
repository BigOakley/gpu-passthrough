# Overview

These are the features and documentation that I know are missing and plan to add as I prioritize them. No set timelines and this list is not for priority

# Documentation

- Command outputs
- GUI install steps for VM
- `virsh` install commands

# Features
- bash scripts for installation
- ansible roles
- `.desktop` file creation
- `virt-manager` without `sudo` or `root` access
- Improve yaml parsing to allow for environment variables in the `user.yml`
  Current `pyyaml` does not handle this by default and requires you to 
  build a contructor to evaluate them. `j2cli` handles environment variables
  in the template file, which is why I am using it as the easy method right
  now
