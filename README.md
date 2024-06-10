# Couchbase One-Click Cluster

Deploy a highly available, enterprise NoSQL database cluster on Akamai Connected Cloud. Couchbase Enterprise Server provides performance at scale, with memory-first architecture, built-in cache, dynamic cluster scaling, and workload isolation. The Couchbase One-Click Cluster deploys a five node cluster, containing three data nodes and two index / query nodes, to quickly scale cloud workloads.

Couchbase Enterprise Server is not free to use in production. Use this contact form for [Couchbase Support](https://www.couchbase.com/pricing/) to activate your license and Couchbase application support. 

## Software Included

| Software  | Version   | Description   |
| :---      | :----     | :---          |
| Couchbase Server - Enterprise  | latest    | NoSQL database |
| Nginx     | latest    | Webserver - Reverse Proxy |
| UFW | latest | IPTables Wrapper |
| Certbot | latest | Free SSL certificate for WebUI |

## Supported Distribution

- Ubuntu 22.04 

## Required Instance Type

Couchbase Enterprise Server requires a minimum of **8 GB of RAM**. Any deployment with an instance with less than 8GB of RAM available will fail. 

## Use our API

Customers can choose to the deploy the Couchbase One-Click Cluster through the Linode Marketplace or directly using API. Before using the commands below, you will need to create an [API token](https://www.linode.com/docs/products/tools/linode-api/get-started/#create-an-api-token) or configure [linode-cli](https://www.linode.com/products/cli/) on an environment.

Make sure that the following values are updated at the top of the code block before running the commands:
- TOKEN
- ROOT_PASS

SHELL:
```
export TOKEN="YOUR API TOKEN"
export ROOT_PASS="aComplexP@ssword"
export SUDO_USERNAME="sudo_user"
export EMAIL_ADDRESS="email@domain.com"
curl -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -X POST -d '{
      "backups_enabled": true,
      "swap_size": 512,
      "image": "linode/ubuntu2204",
      "root_pass": "${ROOT_PASS}",
      "stackscript_id": 1366191,
      "stackscript_data": {
        "token_password": "${TOKEN}"
        "sudo_username": "${SUDO_USERNAME}"
        "email_address": "${EMAIL_ADDRESS}"
        "cluster_size": "5"
      },
      "authorized_users": [
        "myUser",
        "secondaryUser"
      ],
      "booted": true,
      "label": "couchbase-occ",
      "type": "g6-standard-4",
      "region": "us-mia",
      "group": "Linode-Group"
    }' \
https://api.linode.com/v4/linode/instances
```

CLI:
```
export TOKEN="YOUR API TOKEN"
export ROOT_PASS="aComplexP@ssword"
export SUDO_USERNAME="sudo_user"
export EMAIL_ADDRESS="email@domain.com"
linode-cli linodes create \
  --label linode123 \
  --root_pass ${ROOT_PASS} \
  --booted true \
  --stackscript_id 1366191 \
  --stackscript_data '{"token_password": "${TOKEN}","sudo_username": "${SUDO_USERNAME}","email_address": "${EMAIL_ADDRESS}","cluster_size": "5"} \
  --region us-mia \
  --type g6-standard-4 \
  --authorized_users "myUser"
  --authorized_users "secondaryUser"
```

## Resources

- [Couchbase Documentation](https://docs.couchbase.com/home/server.html)
- [Create Linode via API](https://www.linode.com/docs/api/linode-instances/#linode-create)
- [Stackscript referece](https://www.linode.com/docs/guides/writing-scripts-for-use-with-linode-stackscripts-a-tutorial/#user-defined-fields-udfs)