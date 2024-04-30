#!/bin/bash
#This Script is executed in using-Halyard Pod
#File path: /opt/halyard/additional/callCopyBoms.sh
#Dir /opt/halyard/additional/ owned by root. Script executed by spinnaker
echo -n "My host is :"; hostname
cd /tmp

cat >copyBoms.sh <<-"HALEOF"
#Purpose: Copies BOM files to /home/spinnaker/.hal/.boms
echo "This Host is :"
hostname; hostname -i
cd /tmp
CMBOM=$(kubectl get configmap | grep boms | awk '{print $1}')
kubectl get configmap $CMBOM -o "jsonpath={.data['boms\.enc']}" > boms.enc
cat boms.enc | base64 -d | base64 -d > spin-boms.tar.gz
du spin-boms.tar.gz boms.enc
tar -xzvf spin-boms.tar.gz
[ ! -d /home/spinnaker/.hal ] && mkdir -pv /home/spinnaker/.hal 
cp -rv .boms /home/spinnaker/.hal/
echo "DONE - BOM"
HALEOF

HAL=$(kubectl get pods | grep halyard-0 | awk '{print $1}')
#Disable Halyard to pull versions.yml from config www.googleapis.com bucket
kubectl exec $HAL -- bash -c "echo 'spinnaker.config.input.gcs.enabled: false' >> /opt/halyard/config/halyard-local.yml"
kubectl exec $HAL -- bash -c "hal shutdown && hal"
until $HAL_COMMAND --ready; do sleep 10 ; done
chmod +x copyBoms.sh
kubectl cp copyBoms.sh $HAL:/tmp/copyBoms.sh
kubectl exec $HAL -- bash -c "/tmp/copyBoms.sh"

