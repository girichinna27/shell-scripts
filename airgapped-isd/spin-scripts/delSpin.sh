rel='spin'
#set -x
for obj in deploy sts svc job Secret ConfigMap sa rolebinding ; do
  #kubectl get $obj | grep -v NAME | grep -i "$rel" | awk '{print $1}' | xargs kubectl delete $obj;
  objlist=($(kubectl get $obj 2>/dev/null | grep -Ev "(NAME|cm-spinnaker-boms|sa-spinnaker-token)" | grep -i "$rel" | awk '{print $1}'))
  echo $obj items : ${#objlist[@]}
  for item in ${objlist[@]}; do
    echo kubectl delete $obj $item
    #kubectl delete $obj $item
  done
  echo -
done
#set +x
pvlist=($(kubectl get pvc 2>/dev/null | grep -Ev "NAME" | grep -i "$rel" | awk '{print $3}'))

pvclist=($(kubectl get pvc 2>/dev/null | grep -Ev "NAME" | grep -i "$rel" | awk '{print $1}'))
echo pvc items : ${#pvclist[@]}
for item in ${pvclist[@]}; do
  echo kubectl delete pvc $item
  #kubectl delete pvc $item
done

echo pv items : ${#pvlist[@]}
for item in ${pvlist[@]}; do
  echo kubectl delete pv $item
  #kubectl delete pv $item
done

