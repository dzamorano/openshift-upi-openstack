This is a fork from https://github.com/mrobson/openstackupi-openshift

OpenShift 4.1: Fully Automated UPI on OpenStack
===============================================

Technologies: OpenShift 4.1, OpenStack, Ansible

Product: Cloud

Breakdown
---------
This is a fully automated, self-contained, OpenShift 4 Baremetal UPI deployment on OpenStacki.

For more information see:

* [OpenShift 4.1 Baremetal UPI Documentation](https://docs.openshift.com/container-platform/4.1/installing/installing_bare_metal/installing-bare-metal.html#installing-bare-metal/)

System Requirements
-------------------

Prerequisites
-------------
* openstack installed
* openstack user account
* openshift pull secret

Steps
-----

1. Clone the repository to your local system

> git clone git@github.com:dzamorano/openshift-upi-openstack.git

2. Create your `openstack-upi-install-config.yml` file
    - Set your `baseDomain`
    - Set your cluster `name`
    - Set your `pullSecret`
    - Set your `sshKey`

```yaml
apiVersion: v1
baseDomain: <base_domain>
compute:
- name: worker
  platform: {}
  replicas: 3
controlPlane:
  name: master
  platform: {}
  replicas: 3
metadata:
  name: <cluster_name>
networking:
  clusterNetworks:
  - cidr: 10.128.0.0/14
    hostSubnetLength: 9
  machineCIDR: 10.0.0.0/16
  serviceCIDR: 172.30.0.0/16
  type: OpenShiftSDN
platform:
  none: {}
pullSecret: '<pull secret>'
sshKey: |
  ssh-rsa <key>
```

3. From the `openstack-openshift-playbook` directory, configure the variables needed for the installation. The playbooks will create

> vi group_vars/all

```Text
# User for the apiserver instance
user: ""

# forward domain for the cluster
fwd_domain: dzamoran.ocp-osp.lab

# reverse domain for the cluster
rev_domain: 0.0.10.in-addr.arpa

# wildcard domain for the cluster
wild_domain: apps.dzamoran.ocp-osp.lab

# forwarder to access the internet for your private DNS server
forward_dns: ""

# update the /etc/hosts file for cli and console resolution
update_hosts: true

# run the role to wait for bootstrap and the install to complete
wait_for_complete: true

# Extra ssh options
ssh_rsa_instance: ../id_rsa"
extra_ssh_options: '-i {{ ssh_rsa_instance }} -o StrictHostKeyChecking=no'
```

> vi group_vars/openstack

```Text
auth_url: ""
user_domain: ""
project_domain: ""
region: ""
auth_api: ""
osp_cacert: ""
project: ""
ospuser: ""
osppassword: ""
email: address@adminuser.com
ssh_key: "../id_rsa.pub"
master_flavor_name: ""
worker_flavor_name: ""
coreos_image_name: CoreOS
apiserver_flavor: RHEL7.5
network_name: public_net
subnet_name: public_subnet
subnet: 10.0.0
cidr: /24
external_network: ""

ocp_from_version: "4.1.7"
ocp_from_release: "quay.io/openshift-release-dev/ocp-release"
registry_username: registry
registry_password: registry
oc_client: "https://artifacts-openshift-release-4-1.svc.ci.openshift.org/zips/openshift-origin-client-tools-v4.1.0-32ec299-211-linux-64bit.tar.gz"


# parent_proxy_user:
# parent_proxy_pass:
# parent_proxy_host:
# parent_proxy_port:
```

4. Setup the ansible hosts file for the flavor, image and fixed_ip (private openstack subnet) you configured above

```
[utility]

[apiserver]
api flavor=b2.large ignfile=empty.ign image=RHEL7.5 floating_ip=true fixed_ip=10.0.0.230 ansible_connection=local ansible_python_interpreter="{{ ansible_playbook_python }}"

[openshift]
bootstrap flavor=b2.large ignfile=bootstrap-append.ign image=CoreOS floating_ip=true fixed_ip=10.0.0.231 ansible_connection=local
master-0 flavor=b2.large ignfile=master.ign image=CoreOS floating_ip=true fixed_ip=10.0.0.235 ansible_connection=local
master-1 flavor=b2.large ignfile=master.ign image=CoreOS fixed_ip=10.0.0.236 ansible_connection=local
master-2 flavor=b2.large ignfile=master.ign image=CoreOS fixed_ip=10.0.0.237 ansible_connection=local
worker-0 flavor=b2.large ignfile=worker.ign image=CoreOS fixed_ip=10.0.0.240 ansible_connection=local
worker-1 flavor=b2.large ignfile=worker.ign image=CoreOS fixed_ip=10.0.0.241 ansible_connection=local
worker-2 flavor=b2.large ignfile=worker.ign image=CoreOS fixed_ip=10.0.0.242 ansible_connection=local
worker-3 flavor=b2.large ignfile=worker.ign image=CoreOS fixed_ip=10.0.0.243 ansible_connection=local
worker-4 flavor=b2.large ignfile=worker.ign image=CoreOS fixed_ip=10.0.0.244 ansible_connection=local

[openstack]
localhost ansible_connection=local ansible_python_interpreter="{{ ansible_playbook_python }}"

[uninstall:children]
apiserver
openshift

[uninstall:vars]
ansible_python_interpreter="{{ ansible_playbook_python }}"

[all:vars]
ansible_ssh_private_key_file="../id_rsa"
ansible_ssh_user=cloud-user
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

5. Run the playbook

If you set `update_hosts: true`, you need to use `-K` and provide the sudo password for your local machine so it can update the hosts file with entries for the apiserver, console and oauth addresses

> ansible-playbook -i hosts -K site.yml

If you do not want to updateb your hosts file, set `update_hosts: false` in `group_vars/all` and do not use the `-K` flag

The playbook runtime to an install-complete OpenShift cluster, without having to upload and create the CoreOS image, is about 50 minutes

Playbooks
---------

The setup and installation master playbook consists of 4 playbooks with 6 roles

1. Install Master Playbook: This imports the 5 main playbooks for the setup and install
    - `site.yml`

2. Install Playbooks
    - `custom_ca_cert.yml`: Generate private key and create custom root CA files
      - role: `custom_ca_cert`
    - `preflight.yml`: Checks some prerequisites and generates fresh ignition configs for the installation
      - role: `preflight`
    - `openstack.yml`: Builds the openstack environment - project, quotas, user, roles, flavors, keypair, security groups, network, subnet and router
      - role: `openstack`
    - `apiserver.yml`: Creates and configures the apiserver for the environment - osp api instance with external access, private dns server and haproxy loadbalancer for openshift. It also updates the `/etc/hosts` file of your localhost for API access if you set `update_hosts: true` in `group_vars/all`
      - role: `apiserver`
      - role: `hosts` conditional: `update_hosts: true`
      - role: `bind`
      - role: `loadbalancer`
      - role: `registry`
    - `openshift.yml`: Creates the openshift environment - static port allocations, 7 instances and any required floating ips for external access - bootstrap, master0-2, worker0-2
      - role: `openshift`
      - role: `waitforcomplete` conditional: `wait_for_complete: true`

The uninstall playbook has 1 role

3. Uninstall Playbook
    - `uninstall.yml`: Deletes all of the instances, floating ips, port allocations
      - role: `uninstall`

API and Console Access
----------------------

If you do not have proper name resolution from your local machine, you can setup your local hosts file for console and cli access. With `update_hosts: true` and sudo access, this will be updated automatically.

```
<apiserver_public_ip>    api.dzamoran.ocp-osp.lab
<apiserver_public_ip>    console-openshift-console.apps.dzamoran.ocp-osp.lab
<apiserver_public_ip>    oauth-openshift.apps.dzamoran.ocp-osp.lab
```

Uninstall
---------

This removes the entire OpenShift cluster and all of the openstack

> ansible-playbook -i hosts uninstall.yml

The uninstall playbook takes about 2 minutes to remove everything