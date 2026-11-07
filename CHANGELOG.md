# Changelog

## 0.1.0

Unreleased.

- New role `container`: a library role that runs one container as a rootless podman Quadlet unit under its own system
  user (home `/var/lib/<name>`, a non-overlapping subuid/subgid range, lingering). It pulls `container_image` or builds
  `container_build` on the host as that user, writes plain env into the unit and secret env into a 0600 EnvironmentFile,
  and restarts the service when the unit, image or secrets change. It asserts podman >= 4.4 and installs nothing.
- New role `minecraft`: a Paper server whose image is built on the host (mcrcon from source, the Paper jar checked
  against its sha256, Eclipse Temurin 25 JRE). It requires `minecraft_eula: true`, manages `eula.txt` and the
  `server.properties` keys in `minecraft_properties`, and can enable RCON inside the container.
- Molecule scenarios `container` and `minecraft` on Debian 13, Ubuntu 24.04 and 26.04.
