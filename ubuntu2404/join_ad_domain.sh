#!/bin/bash

set -e          # Exit immediately on error
set -u          # Treat unset variables as an error
set -o pipefail # Prevent errors in a pipeline from being masked
IFS=$'\n\t'     # Set the internal field separator to a tab and newline

#permissions required to join domain
#https://wiki.samba.org/index.php/Delegation/Joining_Machines_to_a_Domain

#to call the script
#example sudo join_ad_domain.sh bob password domain.home OU=Linux,OU=SERVERS,OU=ADAdmin


###############
#  Variables  #
###############


readonly joindomain_username=$1
readonly joindomain_password=$2
readonly ad_domain=$3
readonly ad_ou=$4
readonly administrators=$5

echo "#####INSTALLING DOMAIN JOIN PREREQS#######"
apt -qq install realmd packagekit sssd oddjob oddjob-mkhomedir adcli samba-common policykit-1 -y 


echo "#####JOINING TO AD DOMAIN#######"

#join domain, to trouble shoot add --verbose. In some cases it may be necessary to switch to --membership-software=adcli/--membership-software=samba
echo $joindomain_password| realm join $ad_domain --user=$joindomain_username --computer-ou=$ad_ou --verbose --membership-software=samba

#modify sssd settings
cp -f /etc/sssd/sssd.conf "/etc/sssd/sssd_$(date +%F_%R).bak"
sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' /etc/sssd/sssd.conf 
sed -i 's#fallback_homedir = /home/%u@%d#fallback_homedir = /home/AD/%u#' /etc/sssd/sssd.conf 
echo "#to address a known performance bug, details - https://lists.fedorahosted.org/archives/list/sssd-users@lists.fedorahosted.org/thread/4JKLEVV2QSJ3JLYPWIUZWXYOHMQATAYA/" >> /etc/sssd/sssd.conf 
echo "ldap_use_tokengroups = false" >> /etc/sssd/sssd.conf 
systemctl restart sssd

#for ubuntu, ensure users can create home dirs
echo "session optional          pam_mkhomedir.so " >> /etc/pam.d/common-session

#limit ssh login to an ActiveDirectory group instead of default, all domain users
realm permit -g "$administrators"

#add AD group of administrators to sudoers
echo "ADDING SUODER GROUPS"
echo %$administrators  ' ALL =  (ALL)       ALL' | sudo EDITOR='tee -a' visudo

