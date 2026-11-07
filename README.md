# afmigoo.selfhosted

Ansible collection to run self-hosted services on Debian 13 and Ubuntu (24.04,
26.04) as rootless podman containers: one system user per service, each
container a Quadlet unit in that user's systemd.

## Contents

### Roles

| Role | What it does |
|------|--------------|
| `afmigoo.selfhosted.container` | Library role for the app roles: one container per call. Creates the service user (home `/var/lib/<name>`) with a subuid/subgid range and lingering, pulls or builds the image as that user, writes the Quadlet unit and starts it |
| `afmigoo.selfhosted.minecraft` | Paper Minecraft server. Builds its image on the host (mcrcon from source, the Paper jar checked against its sha256, Eclipse Temurin 25 JRE), manages `eula.txt` and chosen `server.properties` keys, runs it with `container` |

Every role is opt-in: it does nothing unless `<role>_enable: true`. Options are
documented in each role's `meta/argument_specs.yml` (`ansible-doc -t role
afmigoo.selfhosted.<role>`). Each role also has a `verification` entry point
(`tasks_from: verification`).

The roles need podman >= 4.4 (Quadlet) on the host and don't install it;
`afmigoo.provision.podman` does. When Ansible logs in as a user other than root,
it also needs `setfacl` (package `acl`) to run tasks as the service user. Debian 12 is
not supported: its podman 4.3 has no Quadlet. Roles never pull in other roles
as dependencies, so playbooks order them; app roles include `container`
themselves. Opening ports in the firewall is up to you (e.g.
`harden_ufw_allowed_ports` in `afmigoo.provision.harden`).

## Install

```sh
ansible-galaxy collection install git+https://github.com/afmigoo/ansible-collection-selfhosted.git
```

or in `requirements.yml`:

```yaml
collections:
  - name: https://github.com/afmigoo/ansible-collection-selfhosted.git
    type: git
    version: main
```

Its dependency `containers.podman` is installed with it.

## Usage

### Minecraft

Install podman with `afmigoo.provision`, then run the server:

```yaml
- name: Minecraft server
  hosts: minecraft
  gather_facts: false
  become: true
  vars:
    podman_enable: true
    minecraft_enable: true
    minecraft_eula: true            # you accept https://aka.ms/MinecraftEULA
    minecraft_memory: 3G
    minecraft_port: 25565
    minecraft_properties:
      motd: My server
      max-players: 10
      difficulty: normal
    minecraft_enable_rcon: true
    minecraft_rcon_password: "{{ vault_minecraft_rcon_password }}"
  roles:
    - role: afmigoo.provision.podman
    - role: afmigoo.selfhosted.minecraft
```

The world and config live in `/var/lib/minecraft/data`, owned by the
`minecraft` system user. Only the keys in `minecraft_properties` are managed
(Paper rewrites `server.properties` and keeps the rest); changing one restarts
the server. `server-port` stays 25565 inside the container, `minecraft_port` is
the host side. A new `minecraft_paper_url`/`minecraft_paper_sha256` pair
rebuilds the image and restarts the server.

Manage the server as its user (it has no login shell):

```sh
sudo -u minecraft XDG_RUNTIME_DIR=/run/user/$(id -u minecraft) systemctl --user status minecraft
sudo -u minecraft XDG_RUNTIME_DIR=/run/user/$(id -u minecraft) journalctl --user -u minecraft -f
sudo -u minecraft XDG_RUNTIME_DIR=/run/user/$(id -u minecraft) podman exec minecraft mcrcon list   # with RCON
```

RCON listens on 25575 inside the container only; the container gets the
password as `MCRCON_PASS`, so `mcrcon` needs no `-p`.

### Container (for app roles)

`container` does nothing alone. An app role includes it once per container,
with its inputs as `vars:` and `apply: tags:` so the app's tags reach it:

```yaml
- name: Run the app container
  ansible.builtin.include_role:
    name: afmigoo.selfhosted.container
    apply:
      tags: [myapp]
  vars:
    container_enable: true
    container_name: myapp                       # user, home /var/lib/myapp, container and unit
    container_image: docker.io/library/nginx:1.29
    # or build on the host instead (tagged localhost/myapp:latest):
    # container_build:
    #   containerfile: "{{ _myapp_containerfile }}"   # rendered in the app role
    #   files: {entrypoint.sh: "..."}                 # extra build context files
    container_ports: ["8080:80/tcp"]
    container_bind: 127.0.0.1                   # default 0.0.0.0
    container_volumes: ["/var/lib/myapp/data:/data"]
    container_env: {TZ: UTC}
    container_secret_env: {API_TOKEN: "{{ vault_myapp_token }}"}   # 0600 EnvironmentFile
    container_extra: ["PodmanArgs=--stop-timeout=30"]              # raw [Container] lines
    container_restart: "{{ __myapp_config is changed }}"           # restart for the app's own config files
  tags: [myapp]
```

The unit lands in `/var/lib/<name>/.config/containers/systemd/<name>.container`.
A changed unit, image or secret env file restarts the service. When the app
role has to write files the user owns before the container first starts, it
creates the user first with `tasks_from: user` (as `minecraft` does).

## Development

```sh
python3 -m venv .venv && . .venv/bin/activate   # or a pyenv env named as in .python-version
make install    # pip packages and collections
make lint       # ansible-lint (production profile)
make syntax     # syntax-check every Molecule scenario
make build      # collection tarball
```

`make` lists every target.

### Molecule tests

`extensions/molecule/` has one scenario per role (`container`, `minecraft`). Each
runs its role alone with the role's test vars, `roles/<role>/vars/test.yml`
(`import_role` with `vars_from: test`; the role never loads that file itself).
A scenario's `prepare.yml` installs podman, which the roles expect. Each boots
three VMs with vagrant-libvirt (Debian 13, Ubuntu 24.04 and 26.04), runs prepare,
converge, idempotence, then the role's `verification` entry point on all of them
at once, and destroys them.

- `container` runs a pulled busybox httpd (1 vCPU each, 1 GiB for Debian, 2 GiB
  for Ubuntu: 3 vCPU, 5 GiB).
- `minecraft` builds the Paper image and starts the server with a 1 GiB heap
  (2 vCPU and 2.25 GiB each: 6 vCPU, 6.75 GiB). Its first start downloads and
  patches the server, so the run takes a while.

```sh
make test-minecraft         # one scenario (molecule test -s minecraft)
make test                   # all of them, one scenario at a time (molecule test --all)
make destroy                # clean up after an interrupted run
```

Don't pass `--workers` above 1 on a small host. The RCON password in
`roles/minecraft/vars/test.yml` is a throwaway, allowlisted for gitleaks in
`.gitleaks.toml`.

Role conventions (variable prefixes, layout, check mode, tags, handlers) follow
the `ansible-roles` skill that `afmigoo.provision.agent_sandbox` installs.
