#!/bin/bash

green='\E[32;40m'

cecho() {
        local default_msg="No message passed."
        message=${1:-$default_msg}
        color=${2:-$green}
        echo -e "$color"
        echo -e "$message"
        tput sgr0

        return
}

cecho "Updating VMware Cloud Builder to support 1-Node Management Domain ..."
echo "bringup.mgmt.cluster.minimum.size=1" >> /etc/vmware/vcf/bringup/application.properties

cecho "Restart VMware Cloud Builder service ..."
systemctl restart vcf-bringup.service

cecho "Umounting /mnt/iso ..."
umount /mnt/iso

cecho "Creating overlay directories ..."
mkdir -p /overlay/{upper,work}
mkdir -p /root/oldiso

cecho "Re-mounting sddc-foundation-bundle.iso to /root/oldiso ..."
mount -o loop /opt/vmware/vcf/iso/sddc-foundation-bundle.iso /root/oldiso

ORIGINAL_NSX_OVA_PATH=$(find /root/oldiso -type f -name "nsx-unified*.ova")
NEW_NSX_OVA_PATH="/overlay/upper/${ORIGINAL_NSX_OVA_PATH#/root/oldiso/}"
NEW_NSX_OVF_PATH="${NEW_NSX_OVA_PATH%.*}.ovf"

cecho "Converting original NSX OVA to OVF ..."
mkdir -p "$(dirname "${NEW_NSX_OVA_PATH}")"
ovftool --acceptAllEulas --allowExtraConfig --allowAllExtraConfig --disableVerification ${ORIGINAL_NSX_OVA_PATH} ${NEW_NSX_OVF_PATH}
rm "${NEW_NSX_OVA_PATH%.ova}.mf"

cecho "Removing memory reservation from NSX OVA ..."
sed -i '/        <rasd:Reservation>.*/d' ${NEW_NSX_OVF_PATH}

cecho "Converting modified NSX OVF to OVA ..."
ovftool --acceptAllEulas --allowExtraConfig --allowAllExtraConfig --disableVerification ${NEW_NSX_OVF_PATH} ${NEW_NSX_OVA_PATH}

cecho "Cleaning up ..."
rm "${NEW_NSX_OVA_PATH%.ova}.ovf"
rm $(dirname "${NEW_NSX_OVA_PATH}")/*.vmdk

cecho "Update permisisons in /mnt/iso & /overlay directory ..."
chown nobody:nogroup -R /overlay/upper
chmod -R 755 /overlay/upper

cecho "Enabling overlay module & mounting new overlay directories ..."
modprobe overlay
mount -t overlay -o lowerdir=/root/oldiso,upperdir=/overlay/upper,workdir=/overlay/work overlay /mnt/iso

cecho "VMware Cloud Builder 1-Node Setup script has completed ..."