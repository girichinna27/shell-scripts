# Airgapped Spinnaker Package 

Package for airgapped installation is generated in a Internet connected machine (x86_AMD) through Docker container. Then package is shipped to Customer's airgapped env. The package is extracted and used for ISD/Spinnaker installation on a airgapped K8s cluster.

## Procedure to Prepare Air-gapped Package

**Assumptions**: You have internet connectivity on your Host machine, and docker is installed.

1. Run a docker container from airgapped image. Result package will be created in the working directory of Host machine, where docker is run  
   `docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/tmp/hostdir -w /tmp/hostdir quay.io/opsmxpublic/airgapped-isd:stable bash`  
   Note: Within the container, all supporting scripts are available at /opt/spin-scripts. Hence, `cd /opt/spin-scripts`

2. Edit the file spin-offline.var   
   - Ensure to input Spinnaker version, and the private docker-registry if you know

3. Edit the file dependencies-and-overrides-pull.yml if required.
   There are three sources of images list. You may edit only the dependencies-and-overrides-pull.yml, other two files are auto-generated.  
     1. Images found in the helm template manifest files (automatically identified and temporarily saved to helm-images-tmp.txt)
     2. Images found in the Spinnaker BOM version file ~/.hal/.boms/bom/<x.y.z>.yml (automatically identified and temporarily saved to spinnaker-images-tmp.txt) 
     3. This file dependencies-and-overrides-pull.yml (manual input if required)  
        Edit this file if you have any override images or additional images to be pulled. Format of the content is below
        ```
        dependencies:
          quay.io/opsmxpublic/ubi8-spin-halyard:opsmx-1.40.0
        spinnaker:
          quay.io/opsmxpublic/ubi8-spin-gate:1.20.0
        opsmx:
          quay.io/opsmxpublic/ubi8-oes-autopilot:v3.8.3

        [or]
         
        #Lines without headings and no leading spaces
        quay.io/opsmxpublic/ubi8-spin-halyard:opsmx-1.40.0
        quay.io/opsmxpublic/ubi8-spin-gate:1.20.0
        quay.io/opsmxpublic/ubi8-oes-autopilot:v3.8.3

        [or]
        #You can also simply keep comments if there are no overrides
        ```
   Note: The image output is saved as $imgname_$imgtag.tar (If tag is unavailable, _$imgtag part is skipped)   

4. Run scripts to generate airgap-bundle.tar
   ``` 
   source spin-offline.var
   bash netspin-pkgoffline.sh 
   ```
   Note: The netspin-pkgoffline.sh script calls the other scripts netspin-getbom.sh (downloads BOM files) and
   netspin-getimages.sh (downloads Docker images). It produces airgap-bundle.tar file, you need to ship this file to Customer's airgapped environment.

## Procedure to install Spinnaker in Air-gapped environment

**Assumptions**: You have docker running in your Host machine in the airgapped env. The Host machine can connect to your Kubernetes cluster where ISD/Spinnaker will be installed.

_Note_: Prior to running steps here, ensure airgap-bundle.tar file is shipped to the Host machine in airgapped env and extracted.
   
1. Run a docker container from airgapped image. Extracted package content will be available in the working directory of Host machine
   ```
   docker load -i airgapped-isd.tar
   # Parsing yaml files require yq tool, which is pre-packaged in the airgapped image.
   docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/tmp/hostdir/ airgapped-isd:latest bash
   ```
2. Edit the file spin-offline.var and push images to private registry
   Note: Within the container, all supporting scripts are available at /opt/spin-scripts. Hence, 
   `cd /opt/spin-scripts`
   - Edit the file spin-offline.var and ensure to input Spinnaker version, and the private docker-registry (this is where the images had to be pushed before installing Spinnaker)
   - Edit the file dependencies-and-overrides-pull.yml to ensure all images are included except the images in Spinnaker ver BOM file
   - Run the scripts  
     ```
     source spin-offline.var  
     bash olspin-pushimages.sh
     ```  
   Note: You can now exit the container.  
3. Prepare values.yaml file with desired changes. Additionally, make sure to update
   - Private Docker registry and passwords
   - Halyard service account and kubeconfig file
   - Disable RBAC and SecurityContext
   - Enable CustomBom and the configmap name
4. Create target namespace and make it as the default one in the current-context (so all our kubectl actions are acted on the namespace)
   ```kubectl create ns offline
   kubectl config set-context --current --namespace=offline #Setcurrent-context to use ‘offline’ namespace```
5. Run pre-install scripts
   ```
   bash preInstallSpin.sh script #Creates a configMap for custom spin-boms.tar.gz file. Also, creates the serviceAccount for halyard along with its kubeconfig secret
   ```   
   Note: The netspin-pkgoffline.sh script calls the other scripts netspin-getbom.sh (downloads BOM files) and netspin-getimages.sh (downloads Docker images)
6. Modify and run installSpin.sh to perform Spinnaker installation. 
   `bash installSpin.sh`


Watch for pod status, expose Spinnaker UI enpoint via ingress or service port-forward

*Installation is now Completed*
