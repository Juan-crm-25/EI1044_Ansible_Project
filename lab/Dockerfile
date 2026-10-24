FROM geerlingguy/docker-ubuntu2204-ansible:latest

# 1. Servidor SSH (Ansible se conecta por SSH)
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server \
 && rm -rf /var/lib/apt/lists/* \
 && systemctl enable ssh

# 2. Usuario "ansible" con sudo sin contraseña
RUN useradd --create-home --shell /bin/bash ansible \
 && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
 && chmod 0440 /etc/sudoers.d/ansible \
 && install -d -m 0700 -o ansible -g ansible /home/ansible/.ssh

# 3. Clave pública autorizada (fichero local, ignorado en Git)
COPY --chown=ansible:ansible --chmod=0600 ssh/authorized_keys /home/ansible/.ssh/authorized_keys

# 4. Evita que systemd del contenedor borre las reglas binfmt del anfitrión
#    (rompería, por ejemplo, la ejecución de .exe en WSL o qemu en Linux)
RUN systemctl mask systemd-binfmt.service

EXPOSE 22
# Heredado de la imagen base; lo dejamos explícito: el contenedor arranca systemd
CMD ["/lib/systemd/systemd"]
