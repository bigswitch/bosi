#!/bin/bash

install_bsnstacklib=%(install_bsnstacklib)s
install_ivs=%(install_ivs)s
install_all=%(install_all)s
deploy_dhcp_agent=%(deploy_dhcp_agent)s
deploy_l3_agent=%(deploy_l3_agent)s
ivs_version=%(ivs_version)s
is_controller=%(is_controller)s
deploy_horizon_patch=false
fuel_cluster_id=%(fuel_cluster_id)s
openstack_release=%(openstack_release)s
deploy_haproxy=%(deploy_haproxy)s
default_gw=%(default_gw)s

rhosp_automate_register=%(rhosp_automate_register)
rhosp_undercloud_dns=%(rhosp_undercloud_dns)
rhosp_register_username=%(rhosp_register_username)
rhosp_register_passwd=%(rhosp_register_passwd)


controller() {
    echo 'Stop and disable metadata agent, dhcp agent, l3 agent'
    sudo pcs resource disable neutron-metadata-agent-clone
    sudo pcs resource disable neutron-metadata-agent
    sudo pcs resource delete neutron-metadata-agent-clone
    sudo pcs resource delete neutron-metadata-agent

    sudo pcs resource disable neutron-dhcp-agent-clone
    sudo pcs resource disable neutron-dhcp-agent
    sudo pcs resource delete neutron-dhcp-agent-clone
    sudo pcs resource delete neutron-dhcp-agent

    sudo pcs resource disable neutron-l3-agent-clone
    sudo pcs resource disable neutron-l3-agent
    sudo pcs resource delete neutron-l3-agent-clone
    sudo pcs resource delete neutron-l3-agent

    # install bsnstacklib
    if [[ $install_bsnstacklib == true ]]; then
        sudo pip install --upgrade "bsnstacklib<%(bsnstacklib_version)s"
    fi
    sudo systemctl stop neutron-bsn-agent

    # deploy bcf
    sudo puppet apply --modulepath /etc/puppet/modules %(dst_dir)s/%(hostname)s.pp

    # restart keystone and httpd
    sudo systemctl restart openstack-keystone
    sudo systemctl restart httpd

    echo 'Restart neutron-server'
    sudo rm -rf /etc/neutron/plugins/ml2/host_certs/*
    sudo systemctl restart neutron-server
}

compute() {

    systemctl stop neutron-l3-agent
    systemctl disable neutron-l3-agent
    systemctl stop neutron-dhcp-agent
    systemctl disable neutron-dhcp-agent
    systemctl stop neutron-metadata-agent
    systemctl disable neutron-metadata-agent

    # patch linux/dhcp.py to make sure static host route is pushed to instances
    adhcp_py=$(find /usr -name dhcp.py | grep linux)
    dhcp_dir=$(dirname "${dhcp_py}")
    sed -i 's/if (isolated_subnets\[subnet.id\] and/if (True and/g' $dhcp_py
    find $dhcp_dir -name "*.pyc" | xargs rm
    find $dhcp_dir -name "*.pyo" | xargs rm

    if [[ $deploy_haproxy == true ]]; then
        sudo groupadd nogroup
        sudo yum install -y keepalived haproxy
        sudo sysctl -w net.ipv4.ip_nonlocal_bind=1
    fi

    # full installation
    if [[ $install_all == true ]]; then
        # deploy bcf
        sudo puppet apply --modulepath /etc/puppet/modules %(dst_dir)s/%(hostname)s.pp

        #TODO: reset uplinks to move them out of bond

        # assign default gw
        sudo bash /etc/rc.d/rc.local

    fi

    if [[ $deploy_dhcp_agent == true ]]; then
        echo 'Restart neutron-metadata-agent, neutron-dhcp-agent and neutron-l3-agent'
        sudo systemctl start neutron-metadata-agent
        sudo systemctl enable neutron-metadata-agent
        sudo systemctl start neutron-dhcp-agent
        sudo systemctl enable neutron-dhcp-agent
    fi

    if [[ $deploy_l3_agent == true ]]; then
        sudo systemctl start neutron-l3-agent
        sudo systemctl enable neutron-l3-agent
    fi

    # restart nova compute on compute node
    echo 'Restart openstack-nova-compute'
    sudo systemctl restart openstack-nova-compute
    sudo systemctl enable openstack-nova-compute

    # stop bsn-agent
    sudo systemctl stop neutron-bsn-agent
}


set +e

# update dns
sudo sed -i "s/^nameserver.*/nameserver $rhosp_undercloud_dns/" /etc/resolv.conf

# assign default gw
sudo ip route del default
sudo ip route del default
sudo ip route add default via $default_gw

# auto register
if [[ $rhosp_automate_register == true ]]; then
    sudo subscription-manager register --username $rhosp_register_username --password $rhosp_register_passwd --auto-attach
fi

sudo subscription-manager version | grep Unknown
if [[ $? == 0 ]]; then
    echo "node is not registered in subscription-manager"
    exit 1
fi

# prepare dependencies
sudo rpm -iUvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
sudo rpm -ivh https://yum.puppetlabs.com/el/7/products/x86_64/puppetlabs-release-7-10.noarch.rpm
sudo yum update -y
sudo yum groupinstall -y 'Development Tools'
sudo yum install -y python-devel puppet python-pip wget libffi-devel openssl-devel ntp
sudo easy_install pip
sudo puppet module install --force puppetlabs-inifile
sudo puppet module install --force puppetlabs-stdlib

if [[ $is_controller == true ]]; then
    controller
else
    compute
fi

set -e

