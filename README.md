# Repo for my infrastructure

## Usage

```shell
# clone this repo
git clone ssh://git@git.adminforge.de:222/maksim/infrastructure.git


cd infrastructure
# rebuild the system
sudo nixos-rebuild switch --flake .#`hostname`
```