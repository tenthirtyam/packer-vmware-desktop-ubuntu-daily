#cloud-config

autoinstall:
  version: 1
  apt:
    geoip: true
    disable_components: []
    preserve_sources_list: false
    primary:
      - arches: [amd64, i386]
        uri: http://us.archive.ubuntu.com/ubuntu
      - arches: [default]
        uri: http://ports.ubuntu.com/ubuntu-ports
  early-commands:
    - sudo systemctl stop ssh
  locale: en_US
  keyboard:
    layout: us
  identity:
    hostname: ${vm_hostname}
    username: ${ssh_username}
    password: ${ssh_password_encrypted}
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - openssh-server
    - open-vm-tools
  user-data:
    disable_root: false
    timezone: UTC
  late-commands:
    - sed -i -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /target/etc/ssh/sshd_config
    - echo '${ssh_username} ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/${ssh_username}
    - curtin in-target --target=/target -- chmod 440 /etc/sudoers.d/${ssh_username}
    - "lvresize -v -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv"
    - "resize2fs -p /dev/mapper/ubuntu--vg-ubuntu--lv"
