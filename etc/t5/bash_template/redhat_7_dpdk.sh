#!/bin/bash -eux
# Copyright 2018 Big Switch Networks, Inc.
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# env variables to be supplied by BOSI
is_controller={is_controller}
dpdk_phy_name={dpdk_phy_name}
system_desc={system_desc}

# constants for this job
SERVICE_FILE_DEFAULT='/usr/lib/systemd/system/neutron-bsn-lldp.service'
SERVICE_FILE_DPDK='/usr/lib/systemd/system/neutron-bsn-lldp-dpdk.service'

# new vars with evaluated results
HOSTNAME=`hostname -f`

# system name for LLDP depends on whether its a controller or compute node
SYSTEMNAME_LINUX_BOND=$HOSTNAME-api
SYSTEMNAME_DPDK_BRIDGE=$HOSTNAME-$dpdk_phy_name

# Make sure only root can run this script
if [ "$(id -u)" != "0" ]; then
   echo -e "Please run as root"
   exit 1
fi

# if service file exists, stop and disable the service. else, return true
systemctl stop neutron-bsn-lldp | true
systemctl disable neutron-bsn-lldp | true

systemctl stop neutron-bsn-lldp-dpdk | true
systemctl disable neutron-bsn-lldp-dpdk | true

# rewrite service file for linux_bond
echo "
[Unit]
Description=bsn lldp
Wants=network-online.target
After=syslog.target network.target network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/bsnlldp --system-name $SYSTEMNAME_LINUX_BOND
Restart=always
StartLimitInterval=60s
StartLimitBurst=3
[Install]
WantedBy=multi-user.target

" > $SERVICE_FILE_DEFAULT

# rewrite service file for DPDK bridge
if [[ $is_controller == true ]]; then
    echo "
[Unit]
Description=bsn lldp dpdk
Wants=network-online.target
After=syslog.target network.target network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/bsnlldp --system-name $SYSTEMNAME_DPDK_BRIDGE --system-desc $system_desc --dpdk-ctrl-bridge
Restart=always
StartLimitInterval=60s
StartLimitBurst=3
[Install]
WantedBy=multi-user.target

" > $SERVICE_FILE_DPDK
else
    echo "
[Unit]
Description=bsn lldp
Wants=network-online.target
After=syslog.target network.target network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/bsnlldp --system-name $SYSTEMNAME_DPDK_BRIDGE --system-desc $system_desc --dpdk-cmpt-bridge
Restart=always
StartLimitInterval=60s
StartLimitBurst=3
[Install]
WantedBy=multi-user.target

" > $SERVICE_FILE_DPDK
fi

# reload service files
systemctl daemon-reload

# start lldp script for linux_bond
systemctl enable neutron-bsn-lldp
systemctl start neutron-bsn-lldp

systemctl enable neutron-bsn-lldp-dpdk
systemctl start neutron-bsn-lldp-dpdk


echo "Finished updating with DPDK LLDP scripts."
