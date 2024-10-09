#!/bin/bash

cat << EOF > ~/ansible/.vault_pass
#!/usr/bin/env python3

import os
print (os.environ['VAULT_PASSWORD'])
EOF

echo "Set the Ansible Vault Password in the environment Variable VAULT_PASSWORD"
#...

ansible-vault create group_vars/bastion/vault

