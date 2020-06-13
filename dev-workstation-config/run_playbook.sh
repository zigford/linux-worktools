#!/bin/bash

ANSIBLE_ROLES_PATH=~/.ansible/roles

ansible-galaxy install -r requirements.yml
ansible-playbook main.yml
