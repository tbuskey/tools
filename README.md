Flexy artifact to CLI login

## Assumptions

* Artifacts downloaded to ~/Download
  * get-flexy-artifacts.sh will grab these from your flexy job
  * hosts.spec
  * kubeadmin-password
  * kubeconfig
  * openshift_install.log
  * client_proxy_setting.sh - IFF it exists
  
## Use
* download all the artifacts from Flexy to ~/Download
  * not needed if you use get-flexy-artifacts.sh!
* mkdir <workdir> && cd <workdir>
* copy setup-ocs.sh and cleanup.sh and get-flexy-artifacts.sh into <workdir>
  * ./get-flexy-artifacts.sh <FlexyID> # instead of manualy downloading
* . setup-ocs.sh

## Result
* move artifacts from ~/Download to current directory
* extract info from artifacts
* download & extract oc from OCP console
* use oc to login to OCP
* show console/password for console
* show cli login command
* creates a kubeconfig named config

You'll have to add the current directory to the PATH to run oc.
You can . setup-ocs.sh repeatedly

## Cleanup
. cleanup.sh
Removes all the artifacts
  
