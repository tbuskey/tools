#!/bin/bash


FLEX=https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/ocp-common/job/Flexy-install
proxy_sh=client_proxy_setting.sh
ID=$1

artifacts='host.spec
workdir/install-dir/.openshift_install.log
workdir/install-dir/auth/kubeadmin-password
workdir/install-dir/auth/kubeconfig
workdir/install-dir/cluster_info.yaml
'

# do . ../cleanup.sh equiv
unset no_proxy
unset http_proxy
unset https_proxy
for i in oc* kube* host.spec openshift_install.log kubeadmin-password kubeconfig cluster_info.yaml $proxy_sh
do
	[ -f $i ] && rm $i
done


for i in $artifacts
do
	wget $FLEX/$ID/artifact/$i
done
mv .openshift_install.log openshift_install.log


