#!/bin/bash
set -e
DEBUG="NO"
if [ "${DEBUG}" == "NO" ]; then
  trap "cleanup $? $LINENO" EXIT
fi

## Deployment Variables
# <UDF name="token_password" label="Your Linode API token" />
# <UDF name="sudo_username" label="The limited sudo user to be created in the cluster" />
# <UDF name="email_address" label="Email Address for CA and Let's Encrypt certificates" example="Example: user@domain.tld" />
# <UDF name="clusterheader" label="Cluster Settings" default="Yes" header="Yes">
# <UDF name="cluster_size" label="Couchbase Server count" default="3" oneOf="3,5,7" />
## ssl variables
# <UDF name="sslheader" label="SSL Information" header="Yes" default="Yes" required="Yes">
# <UDF name="country_name" label="Details for self-signed SSL certificates: Country or Region" oneof="AD,AE,AF,AG,AI,AL,AM,AO,AQ,AR,AS,AT,AU,AW,AX,AZ,BA,BB,BD,BE,BF,BG,BH,BI,BJ,BL,BM,BN,BO,BQ,BR,BS,BT,BV,BW,BY,BZ,CA,CC,CD,CF,CG,CH,CI,CK,CL,CM,CN,CO,CR,CU,CV,CW,CX,CY,CZ,DE,DJ,DK,DM,DO,DZ,EC,EE,EG,EH,ER,ES,ET,FI,FJ,FK,FM,FO,FR,GA,GB,GD,GE,GF,GG,GH,GI,GL,GM,GN,GP,GQ,GR,GS,GT,GU,GW,GY,HK,HM,HN,HR,HT,HU,ID,IE,IL,IM,IN,IO,IQ,IR,IS,IT,JE,JM,JO,JP,KE,KG,KH,KI,KM,KN,KP,KR,KW,KY,KZ,LA,LB,LC,LI,LK,LR,LS,LT,LU,LV,LY,MA,MC,MD,ME,MF,MG,MH,MK,ML,MM,MN,MO,MP,MQ,MR,MS,MT,MU,MV,MW,MX,MY,MZ,NA,NC,NE,NF,NG,NI,NL,NO,NP,NR,NU,NZ,OM,PA,PE,PF,PG,PH,PK,PL,PM,PN,PR,PS,PT,PW,PY,QA,RE,RO,RS,RU,RW,SA,SB,SC,SD,SE,SG,SH,SI,SJ,SK,SL,SM,SN,SO,SR,SS,ST,SV,SX,SY,SZ,TC,TD,TF,TG,TH,TJ,TK,TL,TM,TN,TO,TR,TT,TV,TW,TZ,UA,UG,UM,US,UY,UZ,VA,VC,VE,VG,VI,VN,VU,WF,WS,YE,YT,ZA,ZM,ZW" />
# <UDF name="state_or_province_name" label="State or Province" example="Example: Pennsylvania" />
# <UDF name="locality_name" label="Locality" example="Example: Philadelphia" />
# <UDF name="organization_name" label="Organization" example="Example: Akamai Technologies"  />
# <UDF name="ca_common_name" label="CA Common Name" default="Couchbase CA" />

# git repo
export GIT_REPO="https://github.com/akamai-compute-marketplace/couchbase-occ.git"
export DEBIAN_FRONTEND=non-interactive
export UUID=$(uuidgen | awk -F - '{print $1}')

# enable logging
exec > >(tee /dev/ttyS0 /var/log/stackscript.log) 2>&1

function cleanup {
  if [ "$?" != "0" ] || [ "$SUCCESS" == "true" ]; then
    deactivate
    cd ${HOME}
    if [ -d "/tmp/linode" ]; then
      rm -rf /tmp/linode
    fi
    if [ -f "/usr/local/bin/run" ]; then
      rm /usr/local/bin/run
    fi
  fi
}

function add_privateip {
  echo "[info] Adding instance private IP"
  curl -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${TOKEN_PASSWORD}" \
      -X POST -d '{
        "type": "ipv4",
        "public": false
      }' \
      https://api.linode.com/v4/linode/instances/${LINODE_ID}/ips
}
function get_privateip {
  curl -s -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN_PASSWORD}" \
   https://api.linode.com/v4/linode/instances/${LINODE_ID}/ips | \
   jq -r '.ipv4.private[].address'
}
function configure_privateip {
  LINODE_IP=$(get_privateip)
  if [ ! -z "${LINODE_IP}" ]; then
          echo "[info] Linode private IP present"
  else
          echo "[warn] No private IP found. Adding.."
          add_privateip
          LINODE_IP=$(get_privateip)
          ip addr add ${LINODE_IP}/17 dev eth0 label eth0:1
  fi
}
function rename_provisioner {
  INSTANCE_PREFIX=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .label)
  export INSTANCE_PREFIX="${INSTANCE_PREFIX}"
  echo "[info] renaming the provisioner"
  curl -s -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${TOKEN_PASSWORD}" \
      -X PUT -d "{
        \"label\": \"${INSTANCE_PREFIX}-1-${UUID}\"
      }" \
      https://api.linode.com/v4/linode/instances/${LINODE_ID}
}

function setup {
  # install dependencies
  export DEBIAN_FRONTEND=non-interactive
  apt-get update && apt-get upgrade -y
  apt-get install -y jq git python3 python3-pip python3-dev build-essential
  # add private IP address
  rename_provisioner
  configure_privateip  
  # write authorized_keys file
  if [ "${ADD_SSH_KEYS}" == "yes" ]; then
    curl -sH "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN_PASSWORD}" https://api.linode.com/v4/profile/sshkeys | jq -r .data[].ssh_key > /root/.ssh/authorized_keys
  fi
  # clone repo and set up ansible environment
  git clone ${GIT_REPO} /tmp/linode
  # clone one branch to test 
  # git clone -b develop ${GIT_REPO} /tmp/linode
  cd /tmp/linode
  pip3 install virtualenv
  python3 -m virtualenv env
  source env/bin/activate
  pip install pip --upgrade
  pip install -r requirements.txt
  ansible-galaxy install -r collections.yml
  # copy run script to path
  cp scripts/run.sh /usr/local/bin/run
  chmod +x /usr/local/bin/run
}
# main
setup
run ansible:build
run ansible:deploy && export SUCCESS="true" 