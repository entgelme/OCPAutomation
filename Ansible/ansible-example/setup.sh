#!/bin/bash

MYVAULT="group_vars/all/vault"

cat << EOF > ~/ansible/.vault_pass
#!/usr/bin/env python3

import os
print (os.environ['VAULT_PASSWORD'])
EOF

echo "Setting up a new Ansible Vault ..."
read -p "Enter the password for the new Ansible Vault: " password
export VAULT_PASSWORD=$password
echo "Debug: setting VAULT_PASSWORD to: "$VAULT_PASSWORD

echo "Please enter the key/value pair for 'vault_ocpw, vault_wapw and vault_api_root_pw ...' in the following editor" 
sleep 5

rm $MYVAULT
ansible-vault create $MYVAULT

# Install python modules
# pip install jmespath
# better: as root: dnf install python3-jmespath

# Install ansible modules
ansible-galaxy collection install kubernetes.core redhat.openshift community.okd community.general --ignore-certs

echo "Done!" 
echo -e "Start playbook with:\nVAULT_PASSWORD=abcd ansible-playbook -v -i inventory/hosts.yml --extra-vars '{ clustername: "o1-xxxxxx", ocpw: "kubeadminpassword"}' Rollout-gitops-acm.yml " 
