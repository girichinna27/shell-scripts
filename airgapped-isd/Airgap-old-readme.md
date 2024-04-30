# Airgapped Spinnaker Package 

Scripts here are used to generate Offline/Air-gapped Spinnaker package 

Package for airgapped installation is generated in Internet connected Ubuntu or CentOS machine (VM). Then package is shipped to another Ubuntu/CentOS machine in the same network where airgapped K8s cluster is available.

## Procedure to Prepare Air-gapped Package

* The scripts are executed inside a directory 'airgapped-spinnaker'

1. Edit the file spin-offline.var
   - Ensure to input Spinnaker version, if you know the private docker-registry, input that too
   - Edit the file dependencies-and-overrides-pull.yml to ensure all images are included except the images in Spinnaker ver BOM file
2. Run scripts to generate airgapped-spinnaker.tar.gz
   - source spin-offline.var
   - bash netspin-pkgoffline.sh
   Note: The netspin-pkgoffline.sh script calls the other scripts netspin-getbom.sh (downloads BOM files) and
   netspin-getimages.sh (downloads Docker images). It produces airgapped-spinnaker.tar.gz file, you need to ship this one to airgapped environment.

## Procedure to install Spinnaker in Air-gapped environment

Note: Prior to running steps here, ensure airgapped-spinnaker.tar.gz file is shipped to the airgapped env and extracted.

1. Edit the file spin-offline.var and push images to private registry
   - Ensure to input Spinnaker version, and the private docker-registry (this is where the images had to be pushed before installing Spinnaker)
   - Edit the file dependencies-and-overrides-pull.yml to ensure all images are included except the images in Spinnaker ver BOM file
   - Run the scripts
     `source spin-offline.var`
     `bash olspin-pushimages.sh`
2. Prepare values.yaml file with desired changes. Additionally, make sure to update
   - Private Docker registry and passwords
   - Halyard service account and kubeconfig file
   - Disable RBAC and SecurityContext
   - Enable CustomBom and the configmap name
3. Create target namespace and make it as the default one in the current-context (so all our kubectl actions are acted on the namespace)
   `kubectl create ns offline`
   `kubectl config set-context --current --namespace=offline #Setcurrent-context to use ‘offline’ namespace`
4. Run pre-install scripts
   `bash vagrantPreInstall.sh #Create PVs for data persistence - Not needed in managed Cluster`
   `bash preInstallSpin.sh script #Creates a configMap for custom spin-boms.tar.gz file. Also, creates the serviceAccount for halyard along with its kubeconfig secret`
   Note: The netspin-pkgoffline.sh script calls the other scripts netspin-getbom.sh (downloads BOM files) and
   netspin-getimages.sh (downloads Docker images)
5. Modify and run installSpin.sh to perform Spinnaker installation. 
   `bash installSpin.sh`

Watch for pod status, expose Spinnaker UI enpoint via ingress or service port-forward

*Installation Completed*
