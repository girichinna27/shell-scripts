#!/bin/bash
sname=$(basename $BASH_SOURCE)
sdir=$(cd `dirname $BASH_SOURCE` && pwd)
olroot=${olroot:-$PWD}
tarsdir=$olroot/offlinetars
tmpdir=$olroot/offlinetmp

base64 $tarsdir/spin-boms.tar.gz | base64 - > $tmpdir/halyard-custombom.enc
file $tarsdir/spin-boms.tar.gz $tmpdir/halyard-custombom.enc
du $tarsdir/spin-boms.tar.gz $tmpdir/halyard-custombom.enc

kubectl -n $knamespace create configmap halyard-custombom-configmap --from-file=$tmpdir/halyard-custombom.enc
echo ---
#ServiceAccount config
source generate-kubeconfig.sh
kubectl -n $knamespace create secret generic sec-kubeconfig-sa-spinnaker --from-file=kubeconfig-sa-spinnaker.cfg
