#!/bin/bash
set -e
DEBUG="YES"
if [ "${DEBUG}" == "NO" ]; then
  trap "cleanup $? $LINENO" EXIT
fi

function cleanup {
  if [ "$?" != "0" ]; then
    echo "PLAYBOOK FAILED. See /var/log/stackscript.log for details."
    rm ${HOME}/.ssh/id_ansible_ed25519{,.pub}
    destroy
    exit 1
  fi
}

# constants
readonly VARS_PATH="./group_vars/couchbase/vars"

# utility functions
function destroy {
  if [ -n "${DISTRO}" ] && [ -n "${DATE}" ]; then
    ansible-playbook /tmp/linode/destroy.yml --extra-vars "instance_prefix=${DISTRO}-${DATE}"
  else
    ansible-playbook /tmp/linode/destroy.yml
  fi
}

function ssh_key {
    ssh-keygen -o -a 100 -t ed25519 -C "ansible" -f "${HOME}/.ssh/id_ansible_ed25519" -q -N "" <<<y >/dev/null
    export ANSIBLE_SSH_PUB_KEY=$(cat ${HOME}/.ssh/id_ansible_ed25519.pub)
    export ANSIBLE_SSH_PRIV_KEY=$(cat ${HOME}/.ssh/id_ansible_ed25519)
    export SSH_KEY_PATH="${HOME}/.ssh/id_ansible_ed25519"
    chmod 700 ${HOME}/.ssh
    chmod 600 ${SSH_KEY_PATH}
    eval $(ssh-agent)
    ssh-add ${SSH_KEY_PATH}
    echo -e "\nprivate_key_file = ${SSH_KEY_PATH}" >> ansible.cfg
}

function lint {
  yamllint .
  ansible-lint
  flake8
}

function verify {
    ansible-playbook -i hosts verify.yml
    destroy
}
# adding user tags to all nodes in cluster?
# production
function ansible:build {
  local TEMP_ROOT_PASS=$(openssl rand -base64 32)
  local LINODE_PARAMS=($(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .type,.region,.image))
  local LINODE_TAGS=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .tags)
  ssh_key
  # write vars file
  sed 's/  //g' <<EOF > ${VARS_PATH}
  # account vars
  api_token: ${TOKEN_PASSWORD}
  # cluster vars
  ssh_keys: ${ANSIBLE_SSH_PUB_KEY}
  instance_prefix: ${INSTANCE_PREFIX}
  type: ${LINODE_PARAMS[0]}
  region: ${LINODE_PARAMS[1]}
  image: ${LINODE_PARAMS[2]}
  linode_tags: ${LINODE_TAGS}
  uuid: ${UUID}
  webserver_stack: standalone
  root_pass: ${TEMP_ROOT_PASS}
  server_count: ${CLUSTER_SIZE}
  # user vars
  sudo_username: ${SUDO_USERNAME}
  email_address: ${EMAIL_ADDRESS}
  # ssl generation vars
  country_name: ${COUNTRY_NAME}
  state_or_province_name: ${STATE_OR_PROVINCE_NAME}
  locality_name: ${LOCALITY_NAME}
  organization_name: ${ORGANIZATION_NAME}
  ca_common_name: ${CA_COMMON_NAME}
  # nginx vars
EOF
  if [[ -n ${DOMAIN} ]]; then
    echo "domain: ${DOMAIN}" >> ${VARS_PATH};
  else echo "default_domain: $(hostname -I | awk '{print $1}'| tr '.' '-' | awk {'print $1 ".ip.linodeusercontent.com"'})" >> ${VARS_PATH};
  fi

  if [[ -n ${SUBDOMAIN} ]]; then
    echo "subdomain: ${SUBDOMAIN}" >> ${VARS_PATH};
  else echo "subdomain: www" >> ${VARS_PATH};
  fi
}

function ansible:deploy {
  ansible-playbook -v provision.yml
  ansible-playbook -i hosts site.yml -v
}

function test:deploy {
  export DISTRO="${1}"
  export DATE="$(date '+%Y-%m-%d-%H%M%S')"
  ansible-playbook provision.yml --extra-vars "ssh_keys=${HOME}/.ssh/id_ansible_ed25519.pub instance_prefix=${DISTRO}-${DATE} image=linode/${DISTRO}"
  ansible-playbook -i hosts site.yml --extra-vars "root_password=${TMP_ROOT_PASS}"
}

# main
case $1 in
    ansible:build) "$@"; exit;;
    ansible:deploy) "$@"; exit;;
    test:build) "$@"; exit;;
    test:deploy) "$@"; exit;;
esac
