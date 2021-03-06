#!/bin/bash
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

# Make sure only root can run this script
if [ "$(id -u)" != "0" ]; then
   echo -e "Please run as root"
   exit 1
fi

# source openrc file first

# install packages for centos
python -mplatform | grep centos
if [[ $? == 0 ]]; then
    yum groupinstall -y 'Development Tools'
    sudo rpm -ivh ftp://rpmfind.net/linux/fedora/linux/releases/23/Everything/x86_64/os/Packages/s/sshpass-1.05-8.fc23.x86_64.rpm
    yum install -y python-devel python-yaml python-pip wget
    pip install --upgrade subprocess32 futures
    exit 0
fi

python -mplatform | grep Ubuntu-14.04
if [[ $? == 0 ]]; then
    apt-get install -y puppet python-dev python-yaml sshpass python-pip
    apt-get install -y linux-headers-$(uname -r) build-essential
    pip install --upgrade subprocess32 futures
    apt-get install -y wget
    exit 0
fi

python -mplatform | grep redhat
if [[ $? == 0 ]]; then
    sudo rpm -iUvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
    sudo rpm -ivh https://yum.puppetlabs.com/el/7/products/x86_64/puppetlabs-release-7-10.noarch.rpm
    sudo yum install -y wget ntp sshpass
    sudo yum groupinstall -y 'Development Tools'
    sudo yum install -y python-devel python-yaml python-pip
    sudo pip install --upgrade subprocess32 futures
    exit 0
fi

echo "Unsupported operating system."
