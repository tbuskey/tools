Flexy artifact to CLI login

## Assumptions

* Artifacts downloaded to ~/Download
  * hosts.spec
  * kubeadmin-password
  * kubeconfig
  * openshift_install.log
  * client_proxy_setting.sh - IFF it exists
  
## Use
* download all the artifacts from Flexy to ~/Download
* mkdir <workdir> && cd <workdir>
* copy setup-ocs.sh and cleanup.sh into <workdir>
* . setup-ocs.sh

## Result
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
  
