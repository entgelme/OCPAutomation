#!/bin/bash

cat << EOF > ~/ansible/.vault_pass
#!/usr/bin/env python3

import os
print (os.environ['VAULT_PASSWORD'])
EOF

echo "Setting up a new Ansible Vault ..."
read -p "Enter the password for the new Ansible Vault: " password
export VAULT_PASSWORD=password
echo "Debug: setting VAULT_PASSWORD to: "$VAULT_PASSWORD

echo "Please enter the key/value pair for 'vault_ocpw: ...' in the following editor" 
sleep 3

rm group_vars/bastion/vault
ansible-vault create group_vars/bastion/vault

echo "Done!" 
