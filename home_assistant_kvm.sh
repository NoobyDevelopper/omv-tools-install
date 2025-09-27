#!/bin/bash
set -e

echo "=== Home Assistant OS KVM Installer & Auto-Update OMV7 ==="

# 1️⃣ Détecter interface principale
MAIN_IFACE=$(ip route | grep '^default' | awk '{print $5}')
echo "[+] Interface principale détectée : $MAIN_IFACE"

# 2️⃣ Informations utilisateur
read -p "IP fixe souhaitée pour la VM (ex: 10.0.0.20): " VM_IP
read -p "Gateway (ex: 10.0.0.1): " GW
read -p "Chemin d'installation VM (ex: /docker/docker_DATA/home_assistant): " VM_PATH

mkdir -p "$VM_PATH"
mkdir -p "$VM_PATH/backups"

# 3️⃣ Vérifier bridge br0
if ! ip a | grep -q "br0"; then
    echo "[+] Bridge br0 absent. Création dans /etc/network/interfaces..."
    apt update && apt install -y bridge-utils wget xz-utils qemu-utils
    echo -e "\nauto br0\niface br0 inet static\n    address $VM_IP\n    netmask 255.255.255.0\n    gateway $GW\n    bridge_ports $MAIN_IFACE\n    bridge_stp off\n    bridge_fd 0\n    bridge_maxwait 0" >> /etc/network/interfaces
    echo "[!] Bridge br0 ajouté sur $MAIN_IFACE. Veuillez reboot OMV et relancer ce script après le reboot."
    exit 0
else
    echo "[+] Bridge br0 détecté."
fi

# 4️⃣ Télécharger dernière version officielle HA OS
echo "[+] Récupération de la dernière version officielle..."
LATEST_URL=$(wget -qO- https://api.github.com/repos/home-assistant/operating-system/releases/latest | grep browser_download_url | grep 'haos_ova.*.qcow2.xz' | cut -d '"' -f 4)
IMG_BASENAME=$(basename "$LATEST_URL")
IMG_FILE="$VM_PATH/${IMG_BASENAME%.xz}"

if [ ! -f "$IMG_FILE" ]; then
    echo "[+] Téléchargement de $LATEST_URL..."
    wget -O "$VM_PATH/$IMG_BASENAME" "$LATEST_URL"
    echo "[+] Décompression..."
    xz -d "$VM_PATH/$IMG_BASENAME"
else
    echo "[+] Image HA OS déjà présente : $IMG_FILE"
fi

# 5️⃣ Détecter version HA OS
VERSION=$(echo "$IMG_FILE" | grep -oP '\d+\.\d+\.\d+')
echo "[+] Version détectée : $VERSION"

# 6️⃣ Création cloud-init ISO
CLOUD_DIR="$VM_PATH/cloud-init"
mkdir -p "$CLOUD_DIR"
cat > "$CLOUD_DIR/user-data" << EOF
#cloud-config
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses: [$VM_IP/24]
      gateway4: $GW
      nameservers:
        addresses: [1.1.1.1,1.0.0.1]
EOF
cloud-localds "$VM_PATH/seed.iso" "$CLOUD_DIR/user-data"

# 7️⃣ Vérifier si la VM existe
if virsh dominfo homeassistant >/dev/null 2>&1; then
    echo "[+] VM existante détectée. Création d'un disque temporaire pour mise à jour..."
    UPDATE_DISK="$VM_PATH/hassos_update.qcow2"
    qemu-img create -f qcow2 -b "$IMG_FILE" "$UPDATE_DISK"
    echo "[!] Disque temporaire $UPDATE_DISK créé. Conserver le disque principal pour données persistantes."
    echo "Vous pouvez ajouter $UPDATE_DISK comme second disque dans virt-manager et tester la mise à jour."
else
    echo "[+] Création de la VM Home Assistant OS..."
    virt-install \
      --name homeassistant \
      --ram 4096 \
      --vcpus 2 \
      --cpu host \
      --os-variant generic \
      --disk path="$IMG_FILE",bus=virtio,format=qcow2 \
      --disk path="$VM_PATH/seed.iso",device=cdrom \
      --network bridge=br0,model=virtio \
      --graphics none \
      --boot uefi \
      --import \
      --noautoconsole

    # Auto-start
    virsh autostart homeassistant

    # Backup initial
    cp "$IMG_FILE" "$VM_PATH/backups/$(date +%F)_hassos.qcow2"
    echo "[+] VM créée et backup initial fait."
fi

echo "=== Script terminé ==="
echo "VM IP fixe : $VM_IP"
echo "Démarrer VM : virsh start homeassistant"
echo "Accéder à HA : http://$VM_IP:8123"
echo "Version HA OS détectée : $VERSION"
