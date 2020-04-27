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


# RPM runs as root and doesn't like source files owned by a random UID
OUTER_UID=$(stat -c '%u' /bosi)
OUTER_GID=$(stat -c '%g' /bosi)
trap "chown -R $OUTER_UID:$OUTER_GID /bosi" EXIT
chown -R root:root /bosi

cd /bosi
git config --global user.name "Big Switch Networks"
git config --global user.email "support@bigswitch.com"

CURR_VERSION=$(awk '/^version/{print $3}' setup.cfg)

echo 'CURR_VERSION=' $CURR_VERSION
git tag -f -s $CURR_VERSION -m $CURR_VERSION -u "Big Switch Networks"

python setup.py sdist

# get packages for offline installation
mkdir -p bosi_offline/dependencies
pip install --download bosi_offline/dependencies --requirement requirements.txt
cp dist/* bosi_offline/
tar -zcvf bosi_offline_packages_$CURR_VERSION.tar.gz bosi_offline

# force success. but always check if pip install fails
twine upload dist/* -r pypi -s -i "Big Switch Networks" || true
# delay of 30 seconds
sleep 30
pip install --upgrade bosi==$CURR_VERSION
if [ "$?" -eq "0" ]
then
  echo "PYPI upload successful."
else
  echo "PYPI upload FAILED. Check the logs."
fi
# remove the package
pip uninstall -y bosi

# $GIT_BRANCH is set by jenkins
# possible values are origin/master, origin/bcf-3.7.0, origin/bcf-4.0.0 and so on..
# convert to canonical bcf_version format as master, 3.7.0, 4.0.0 and so on..
BCF_BRANCH=`echo "$GIT_BRANCH" | rev | cut -d'/' -f 1 | cut -d'-' -f 1 | rev`


# Prepare packages for rsync
OUTDIR=$(readlink -m "/bosi/dist/$BCF_BRANCH/$CURR_VERSION")
rm -rf "$OUTDIR" && mkdir -p "$OUTDIR"
mv /bosi/dist/*.tar.gz "$OUTDIR"
mv /bosi/dist/*.tar.gz.asc "$OUTDIR"
cp -r /bosi/bosi/rhosp_resources "$OUTDIR"
cp bosi_offline_packages_$CURR_VERSION.tar.gz "$OUTDIR"

git log > "$OUTDIR/gitlog.txt"
touch "$OUTDIR/build-$CURR_VERSION"
ln -snf $(basename $OUTDIR) $OUTDIR/../latest

# revert the permissions
chown -R $OUTER_UID:$OUTER_GID /bosi
