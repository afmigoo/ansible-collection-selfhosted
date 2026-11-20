# Changelog

## 0.1.0

- New role `container`: a library role that runs one container as a rootless podman Quadlet unit under its own
  system account `container_user` (default `selfhosted-<container_name>`, home `container_base_dir/<container_name>`,
  default base dir `/var/lib/selfhosted`), namespaced so it can't collide with a distro account or another service's
  user (e.g. a plain `postgres`). The account gets a non-overlapping subuid/subgid range and lingering. Before
  touching it, the role looks the account up and fails instead of modifying it if it already exists with a
  different home. It pulls `container_image` or builds `container_build` on the host as that user, writes plain env
  into the unit and secret env into a 0600 EnvironmentFile, and restarts the service when the unit, image or secrets
  change. It asserts podman >= 4.4 and installs nothing. The container, image and unit names still come from
  `container_name` alone.
- New role `minecraft`: a Paper or Fabric server (`minecraft_backend`) whose image is built on the host (mcrcon from
  source, Eclipse Temurin 25 JRE). `minecraft_backend_spec` overrides single keys of the backend's pinned defaults:
  Paper 26.3 build 244, its jar checked against its sha256; Fabric 26.3 with loader 0.20.1, its installer 1.1.2
  checked against its sha256 and run while the image builds, and `mods`, a list of `{url, sha256}` downloaded to
  `data/mods` (checked when a sha256 is given, never deleted). Each backend also takes `template`, its Containerfile
  template, and `template_args`, extra variables for it. It requires `minecraft_eula: true`, manages `eula.txt`
  and the `server.properties` keys in `minecraft_properties`, and can enable RCON inside the container. Its data lives
  in `/var/lib/selfhosted/<minecraft_name>/data`, owned by `minecraft_user` (default `selfhosted-<minecraft_name>`),
  which it passes to `container` as `container_user`.
- Molecule scenarios `container` and `minecraft` (Paper) on Debian 13, Ubuntu 24.04 and 26.04, `minecraft-fabric`
  (Fabric with two mods) on Debian 13, and `playbook-minecraft_full`, which runs that playbook on bare hosts of all
  three. `container` also checks that the role refuses to touch a foreign account whose name collides with a default
  `container_user`.
- Playbooks `afmigoo.selfhosted.minecraft` (the role only), `afmigoo.selfhosted.minecraft_full` (base setup and
  hardening from `afmigoo.provision.base` and `harden`, hardening on by default with the Minecraft port open in ufw and
  `-e harden_enable=false` to skip it, podman from `afmigoo.provision.podman`, then the role) and
  `afmigoo.selfhosted.verify`.
- Depends on `afmigoo.provision` (git, tag v0.4.1) for the `*_full` playbooks.
- CI on GitHub Actions, as in afmigoo.provision: ansible-lint, building and installing the collection and
  syntax-checking its playbooks, gitleaks, actionlint, zizmor and a changelog check. Dependabot for pip and actions, one
  grouped PR per ecosystem.
