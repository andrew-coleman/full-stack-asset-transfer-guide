#
# Copyright contributors to the Hyperledgendary Full Stack Asset Transfer project
#
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
# 	  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


# Main justfile to run all the scripts
#
# To install 'just' see https://github.com/casey/just#installation


# Ensure all properties are exported as shell env-vars
set export

# set the current directory, and the location of the test dats
CWDIR := justfile_directory()

_default:
  @just --list

bootstrap:
    #!/bin/bash


cluster_name := "kind"

# Starts a local KIND Kubernetes cluster
# Installs Nginx ingress controller
# Adds a DNS override in kube DNS for *.localho.st -> Nginx LB IP
kind:
    infrastructure/kind_with_nginx.sh {{cluster_name}}

unkind:
    #!/bin/bash
    kind delete cluster --name {{cluster_name}}


# Installs and configures a sample Fabric Network
sample-network: console
    #!/bin/bash
    set -ex -o pipefail

    docker run \
        --rm \
        -u $(id -u) \
        -v ${HOME}/.kube/:/home/ibp-user/.kube/ \
        -v ${CWDIR}/infrastructure/fabric_network_playbooks:/playbooks \
        -v ${CWDIR}/_cfg:/_cfg \
        --network=host \
        ofs-ansible:latest \
            ansible-playbook /playbooks/00-complete.yml


# Install the operations console and fabric-operator
console: operator
    #!/bin/bash
    set -ex -o pipefail

    docker run \
        --rm \
        -v ${HOME}/.kube/:/home/ibp-user/.kube/ \
        -v $(pwd)/infrastructure/operator_console_playbooks:/playbooks \
        --network=host \
        ofs-ansible:latest \
            ansible-playbook /playbooks/01-operator-install.yml

    docker run \
        --rm \
        -v ${HOME}/.kube/:/home/ibp-user/.kube/ \
        -v $(pwd)/infrastructure/operator_console_playbooks:/playbooks \
        --network=host \
        ofs-ansible:latest \
            ansible-playbook /playbooks/02-console-install.yml

    AUTH=$(curl -X POST https://fabricinfra-hlf-console-console.localho.st:443/ak/api/v2/permissions/keys -u admin:password -k -H 'Content-Type: application/json' -d '{"roles": ["writer", "manager"],"description": "newkey"}')
    KEY=$(echo $AUTH | jq .api_key | tr -d '"')
    SECRET=$(echo $AUTH | jq .api_secret | tr -d '"')

    echo "Writing authentication file for Ansible based IBP (Software) network building"
    mkdir -p _cfg
    cat << EOF > $CWDIR/_cfg/auth-vars.yml
    api_key: $KEY
    api_endpoint: http://fabricinfra-hlf-console-console.localho.st/
    api_authtype: basic
    api_secret: $SECRET
    EOF
    cat ${CWDIR}/_cfg/auth-vars.yml


# Just install the fabric-operator
operator:
    #!/bin/bash
    set -ex -o pipefail

    docker run \
        --rm \
        -v ${HOME}/.kube/:/home/ibp-user/.kube/ \
        -v $(pwd)/infrastructure/operator_console_playbooks:/playbooks \
        --network=host \
        ofs-ansible:latest \
            ansible-playbook /playbooks/01-operator-install.yml
