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

cecho "Enabling overlay module & mounting new overlay directories ..."
modprobe overlay
mount -t overlay -o lowerdir=/root/oldiso,upperdir=/overlay/upper,workdir=/overlay/work overlay /mnt/iso

ORIGINAL_NSX_OVA_PATH=$(find /mnt/iso -print | grep nsx-unified)
ORIGINAL_NSX_OVA_BASEPATH=$(dirname ${ORIGINAL_NSX_OVA_PATH})
ORIGINAL_NSX_OVA_FILENAME=$(basename ${ORIGINAL_NSX_OVA_PATH})
ORIGINAL_NSX_OVF_FILENAME="${ORIGINAL_NSX_OVA_FILENAME%.*}.ovf"

NEW_NSX_OVA_PATH=$(echo ${ORIGINAL_NSX_OVA_PATH} | sed 's#/mnt/iso/#/overlay/work/work/#g')
NEW_NSX_OVA_BASEPATH=$(dirname ${NEW_NSX_OVA_PATH})
NEW_NSX_OVF_PATH="${NEW_NSX_OVA_BASEPATH}/${ORIGINAL_NSX_OVF_FILENAME}"
NEW_NSX_OVA_PATH="${NEW_NSX_OVA_BASEPATH}/${ORIGINAL_NSX_OVA_FILENAME}"

cecho "Converting original NSX OVA to OVF ..."
mkdir -p ${NEW_NSX_OVA_BASEPATH}
ovftool --acceptAllEulas --allowExtraConfig --allowAllExtraConfig --disableVerification ${ORIGINAL_NSX_OVA_PATH} ${NEW_NSX_OVF_PATH}
rm ${NEW_NSX_OVA_BASEPATH}/*.mf

cecho "Removing memory reservation from NSX OVA ..."
sed -i '/        <rasd:Reservation>.*/d' ${NEW_NSX_OVF_PATH}

cecho "Converting modified NSX OVF to OVA ..."
ovftool --acceptAllEulas --allowExtraConfig --allowAllExtraConfig --disableVerification ${NEW_NSX_OVF_PATH} ${NEW_NSX_OVA_PATH}

cecho "Cleaning up ..."
rm ${NEW_NSX_OVA_BASEPATH}/*.ovf
rm ${NEW_NSX_OVA_BASEPATH}/*.vmdk

cecho "Update permisisons in /mnt/iso & /overlay directory ..."
chown nobody:nogroup -R /overlay/work
chmod -R 755 /overlay/work
chown nobody:nogroup -R /mnt/iso
chmod -R 755 /mnt/iso

cecho "VMware Cloud Builder 1-Node Setup script has completed ..."
