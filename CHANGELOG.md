# Changelog

## 0.1.0

Unreleased.

- New role `container`: a library role that runs one container as a rootless podman Quadlet unit under its own
  system account `container_user` (default `selfhosted-<container_name>`, home `container_base_dir/<container_name>`,
  default base dir `/var/lib/selfhosted`), namespaced so it can't collide with a distro account or another service's
  user (e.g. a plain `postgres`). The account gets a non-overlapping subuid/subgid range and lingering. Before
  touching it, the role looks the account up and fails instead of modifying it if it already exists with a
  different home. It pulls `container_image` or builds `container_build` on the host as that user, writes plain env
  into the unit and secret env into a 0600 EnvironmentFile, and restarts the service when the unit, image or secrets
  change. It asserts podman >= 4.4 and installs nothing. The container, image and unit names still come from
  `container_name` alone.
- New role `minecraft`: a Paper server whose image is built on the host (mcrcon from source, the Paper jar checked
  against its sha256, Eclipse Temurin 25 JRE). It requires `minecraft_eula: true`, manages `eula.txt` and the
  `server.properties` keys in `minecraft_properties`, and can enable RCON inside the container. Its data lives in
  `/var/lib/selfhosted/<minecraft_name>/data`, owned by `minecraft_user` (default `selfhosted-<minecraft_name>`),
  which it passes to `container` as `container_user`.
- Molecule scenarios `container` and `minecraft` on Debian 13, Ubuntu 24.04 and 26.04. `container` also checks that
  the role refuses to touch a foreign account whose name collides with a default `container_user`.
