set -e

# only run once during deployment
if [ -f ./azAutomationComplete ]; then
    echo "STIG Automation completion detected, exiting..."
    exit 0
fi

# apt-get update to assist nxPackage dsc automation
echo "Executing apt-get update..."
apt-get update -q > ./aptgetupdateresults.log

# dsc deployment automation
echo "Move (OS Specific) .mof to configuration store as Pending.mof..."
mv ./*.mof /etc/opt/omi/conf/dsc/configuration/Pending.mof
echo "Execute Register.py --RefreshMode Push --ConfigurationMode ApplyOnly..."
/opt/microsoft/dsc/Scripts/Register.py --RefreshMode Push --ConfigurationMode ApplyOnly > ./dscresults.log
echo "Execute PerformRequiredConfigurationChecks.py to apply the Pending.mof configuration..."
/opt/microsoft/dsc/Scripts/PerformRequiredConfigurationChecks.py >> ./dscresults.log
if grep -q "MI_RESULT_FAILED" ./dscresults.log; then
    echo "Failed to apply Desired State Configuration successfully, check dscresults.log for more details..."
else
    echo "Applied Desired State Configuration successfully..."
fi

# authentication/password/session automation
echo "Creating /etc/pam.d/common-password to meet STIG requirements..."
mv --force /etc/pam.d/common-password /etc/pam.d/backup.common-password
echo "# Generated by Microsoft.Azure.Extensions/CustomScript" > /etc/pam.d/common-password
echo "# Original common-password was moved to /etc/pam.d/backup.common-password" >> /etc/pam.d/common-password
echo "password\trequisite\t\t\tpam_pwquality.so retry=3 enforce_for_root" >> /etc/pam.d/common-password
echo "password\t[success=1 default=ignore]\tpam_unix.so obscure sha512 shadow remember=5 rounds=5000" >> /etc/pam.d/common-password
echo "password\trequired\t\t\tpam_permit.so" >> /etc/pam.d/common-password
echo "Creating /etc/pam.d/common-auth to meet STIG requirements..."
mv --force /etc/pam.d/common-auth /etc/pam.d/backup.common-auth
echo "# Generated by Microsoft.Azure.Extensions/CustomScript" > /etc/pam.d/common-auth
echo "# Original common-auth was moved to /etc/pam.d/backup.common-auth" >> /etc/pam.d/common-auth
echo "auth\trequired\t\t\tpam_tally2.so onerr=fail deny=3" >> /etc/pam.d/common-auth
echo "auth\trequired\t\t\tpam_faildelay.so delay=4000000" >> /etc/pam.d/common-auth
echo "auth\t[success=1 default=ignore]\tpam_unix.so nullok_secure" >> /etc/pam.d/common-auth
echo "auth\trequisite\t\t\tpam_deny.so" >> /etc/pam.d/common-auth
echo "auth\trequired\t\t\tpam_permit.so" >> /etc/pam.d/common-auth
echo "auth\toptional\t\t\tpam_cap.so" >> /etc/pam.d/common-auth
echo "# auth\t[success=2 default=ignore]\tpam_pkcs11.so" >> /etc/pam.d/common-auth
echo "Adding 'session required pam_lastlog.so showfailed' after session pam_selinux.so module in /etc/pam.d/login..."
sed -i 's/\(session.*pam_selinux\.so close\)/\1\nsession required pam_lastlog.so showfailed/g' /etc/pam.d/login
echo "Removing 'NOPASSWD' tag from all files in /etc/sudors.d/"
grep -r -l -i nopasswd /etc/sudoers.d/* | xargs sed -i 's/\s*NOPASSWD://g'
echo "Executing useradd -D -f 35..."
useradd -D -f 35

# file system permissions automation
echo "Setting permissions to all log files under /far/log to 640..."
find /var/log -perm /137 -type f -exec chmod -c 640 '{}' \;
echo "Setting mode to 0750 for /var/log..."
chmod -c 0750 /var/log
echo "Setting group ownership to root for /lib, /usr/lib and /lib64..."
find /lib /usr/lib /lib64 ! -group root -type f -exec chgrp -c root '{}' \;
echo "Setting ownership to root for /bin, /sbin, /usr/bin, /usr/sbin, /usr/local/bin and /usr/local/sbin..."
set +e
find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin ! -user root -type f -exec chown -c root '{}' \;
echo "Setting group ownership to root for /bin, /sbin, /usr/bin, /usr/sbin, /usr/local/bin and /usr/local/sbin..."
find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin ! -group root -type f -exec chgrp -c root '{}' \;
set -e
echo "Setting mode to 0600 for /var/log/audit/*..."
chmod -c 0600 /var/log/audit/*

# chmod persistent cloud-init per-boot script
if [ ! -f /var/lib/cloud/scripts/per-boot/per-boot.sh ]; then
    echo "Writing /var/lib/cloud/scripts/per-boot/per-boot.sh to address chmod persistence post reboot..."
    echo '#!/bin/bash' > /var/lib/cloud/scripts/per-boot/per-boot.sh
    echo 'echo $(date) > /var/log/cloud-init-per-boot.log' >> /var/lib/cloud/scripts/per-boot/per-boot.sh
    echo 'find /var/log -perm /137 -type f -exec chmod -c 640 '{}' \; >> /var/log/cloud-init-per-boot.log' >> /var/lib/cloud/scripts/per-boot/per-boot.sh
    echo 'chmod -c 0750 /var/log >> /var/log/cloud-init-per-boot.log' >> /var/lib/cloud/scripts/per-boot/per-boot.sh
    echo 'chmod -c 0600 /var/log/audit/* >> /var/log/cloud-init-per-boot.log' >> /var/lib/cloud/scripts/per-boot/per-boot.sh
    chmod +x /var/lib/cloud/scripts/per-boot/per-boot.sh
fi

# boot / audit automation
echo "Adding 'audit=1' to /etc/default/grub to enable auditing at system startup..."
cp --force /etc/default/grub /etc/default/backup.grub
sed -i 's/\(GRUB_CMDLINE_LINUX="\)/\1audit=1/g' /etc/default/grub
update-grub 2> ./updategrubresults.log

# system reboot
echo "Rebooting to apply STIG settings..."
touch ./azAutomationComplete
shutdown -r +1 2>&1