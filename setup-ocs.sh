#!/bin/bash

# restart from scratch:
# run cleanup.sh: rm host.spec kube* oc* config openshift_install.log
#unset HTTP_PROXY
#unset HTTPS_PROXY
#unset http_proxy
#unset https_proxy
#no_proxy=localhost,127.0.0.0,127.0.1.1,127.0.1.1,local.home

# app.ci cluster: https://console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com/
# login with github for personal account
# copy login -> back to login -> click github
# Display Token:
#    oc login --token=<YOUR TOKEN> --server=https://api.ci.l2s4.p1.openshiftapps.com:6443

export KUBECONFIG="$PWD/config"
#alias oc='./oc'
proxy_sh=client_proxy_setting.sh
artifacts="kubeconfig kubeadmin-password host.spec openshift_install.log $proxy_sh"
DOWNLOADS="$HOME/Downloads"
err=0
errfile=""
proxy=1
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/legacy_credentials/tbuskey@redhat.com/adc.json 

if [ -x ../openshift-tests ]
then
    alias openshift-tests='../openshift-tests'
fi

if [ -x openshift-tests ]
then
    alias openshift-tests='./openshift-tests'
fi

if [ ! -f config ]
then
    echo "Creating $KUBECONFIG"
cat <<EOF > config
apiVersion: v1
clusters:
contexts:
current-context:
kind: Config
preferences: {}
users:
EOF
fi

for i in $artifacts
do
    if [ ! -f $i ]
    then
	if [ -f $DOWNLOADS/$i ]
	then
	    mv $DOWNLOADS/$i .
	    echo moved $i
	fi
    fi
    if [ ! -f $i ]
    then
	echo missing $i
	err=$(expr $err + 1)
	errfile="$i $errfile"
    fi
done

#api.tbuskey-qe.qe.devcluster.openshift.com:lb
if [ ! -f host.spec ]  # we can create it from other sources
then
    if [  -f kubeconfig ]
    then
	grep server: kubeconfig | sed 's/^.*https...//' | sed 's/6443$/lb/'  > host.spec
    else
	var=$(grep 'https://console' openshift_install.log | sed 's/.*console.apps//' | tr -d '"')
	echo "api${var}:lb" > host.spec
    fi
fi

if [ ! -f kubeadmin-password ]
then
    if [ -f openshift_install.log ]
    then
	var=$(grep passw openshift_install.log | awk '{print $NF}' | tr -d '["\\]')
	echo $var > kubeadmin-password
	echo "Derived passwd: $var"
    else
	echo "no kubeadmin-password"
    fi
fi

# get clustername from host.spec
grep -q , host.spec
var=$?
if [ $var -eq 0 ]
then
    # Proxies mess up host.spec
    # split it on , 1st
    export clustername=$(cut -d, -f2 host.spec | cut -d: -f1 )
    proxy=0
    if [ ! -f $proxy_sh ]
    then
	echo "Grab $proxy_sh and rerun"
	err=$(expr $err + 1)
	errfile="$proxy_sh $errfile"
    fi	
else    
    export clustername=$(cut -d: -f1 host.spec)
fi

export INSTANCE_NAME_PREFIX=$(echo $clustername | cut -d. -f2)
export cloud=$(echo $clustername | cut -d. -f4)
#export console=$(grep https://console openshift_install.log  | sed 's/^.*https:/https:/' | sed 's/health.*$//' | tr -d '"' )
# no, we have host.spec -> clustername.  Use it!
export console=$(echo $clustername | sed 's@^api@https://console-openshift-console.apps@')

unset oc_source

case $cloud in
    devcluster)
	export oc_source="downloads-openshift-console.apps.$INSTANCE_NAME_PREFIX.qe.devcluster.openshift.com"
	;;
    azure)
	export oc_source="downloads-openshift-console.apps.$INSTANCE_NAME_PREFIX.qe.$cloud.devcluster.openshift.com"
	export AZURE_AUTH_LOCATION=~/working/azure.json 
	;;
    qe)
	echo "rhcloud"
	export oc_source=$(echo $clustername |sed 's/api/downloads-openshift-console.apps/')	
	;;
    *)
	export oc_source="downloads-openshift-console.apps.$INSTANCE_NAME_PREFIX.qe.$cloud.devcluster.openshift.com"
	;;
esac
	
echo "clustername=$clustername
INSTANCE_NAME_PREFIX=$INSTANCE_NAME_PREFIX
cloud=$cloud
console=$console
oc_source=$oc_source
"


if [ $proxy -eq 0 ]
then
    if [ -f $proxy_sh ]
    then
	. ./$proxy_sh
    else
	echo "Grab $proxy_sh and rerun"
    fi
fi

# do we need odo?
#[ ! -f odo-linux-amd64.tar.gz ] && wget --no-check-certificate https://mirror.openshift.com/pub/openshift-v4/clients/odo/latest/odo-linux-amd64.tar.gz
#[ ! -x odo ] && tar xvf odo-linux-amd64.tar.gz

[ ! -f oc.tar ] && yes | wget --no-check-certificate https://$oc_source/amd64/linux/oc.tar

[ ! -x oc ] && tar xf oc.tar
   
if [ $proxy -eq 0 ]
then
    echo "http_proxy is $http_proxy"
    echo $http_proxy | tr '[:@/]' ' '
fi

if [ ! -x oc ]
then
    echo "I don't see ./oc.  Check for proxy"
else    
    ./oc login $clustername:6443 -u kubeadmin -p $(cat kubeadmin-password) --insecure-skip-tls-verify=true
    login=$?
    if [ $login -ne 0 ]
    then
	echo "Could not login to  $clustername:6443"
    else
	echo '------------'
	./oc version
	echo ''
	echo ''
	echo $console
	echo ''
	cat kubeadmin-password
	echo ''

	export oc_catalog=$(./oc get pods -n openshift-operator-lifecycle-manager | awk '/catalog/{print $1}')

	export oc_olm=$(./oc get pods -n openshift-operator-lifecycle-manager | awk '/olm-operator/{print $1}')
	export oc_prom_token=$(./oc sa get-token prometheus-k8s -n openshift-monitoring)
    fi
fi

if [ $proxy -eq 0 ]
then
    echo "http_proxy is $(echo $http_proxy | tr '[:@/]' ' ')"
fi

if [ $err -ne 0 ]
then
    cat <<EOF
Download these $errfile from your Jenkins build into $DOWNLOADS:
$artifacts
EOF
fi

    echo '---------------'
    echo "oc login $clustername:6443 -u kubeadmin -p $(cat kubeadmin-password) --insecure-skip-tls-verify=true"
    echo '---------------'

echo $err
echo "Update opm upstream: /home/tbuskey/go/src/github.com/tbuskey/operator-registry/bin/opm to ~/working"
echo "$PATH"
echo 'PATH=$PWD:$PATH'
echo 'PATH=$PWD:/home/tbuskey/bin/linux:/home/tbuskey/bin:/bin:/usr/bin:/sbin:/usr/sbin:/etc:/usr/local/bin:/usr/local/sbin:/usr/local/go/bin:/home/tbuskey/go/bin:/home/tbuskey/working'
