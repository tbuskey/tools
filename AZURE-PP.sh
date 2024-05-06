#!/bin/bash
TMPFILE=aztmp

# L the location of your fork of
# https://github.com/openshift/openshift-tests-private
#
L=/home/tbuskey/go/src/github.com/tbuskey/openshift-tests-private/test/extended/testdata/kata

# export AZURE_SUBSCRIPTION_ID=$(cat ~/.azure/azureProfile.json  | jq -r '.subscriptions[0].id')
export AZURE_SUBSCRIPTION_ID=$(az account list --query "[?isDefault].id" -o tsv)

# this doesn't need to be redone daily
if [ ! -f $TMPFILE ]; then
  az ad sp create-for-rbac --role Contributor --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID --query "{ client_id: appId, client_secret: password, tenant_id: tenant }" | tee $TMPFILE
fi

export AZURE_CLIENT_ID=$(awk '/client_id/{print $NF}' $TMPFILE | tr -d '["',])
export AZURE_CLIENT_SECRET=$(awk '/client_secret/{print $NF}' $TMPFILE | tr -d '["',]) # the client_secret above
export AZURE_TENANT_ID=$(awk '/tenant_id/{print $NF}' $TMPFILE | tr -d '["',])         # the tenant_id above

oc create ns openshift-sandboxed-containers-operator
oc project openshift-sandboxed-containers-operator

# per cluster
export AZURE_RESOURCE_GROUP=$(oc get infrastructure/cluster -o jsonpath='{.status.platformStatus.azure.resourceGroupName}')
export AZURE_STORAGE_ACCOUNT=$(az storage account list -g $AZURE_RESOURCE_GROUP --query "[].{Name:name} | [? contains(Name,'cluster')]" --output tsv)
export AZURE_REGION=$(az group show --resource-group $AZURE_RESOURCE_GROUP --query "{Location:location}" --output tsv)
export AZURE_STORAGE_EP=$(az storage account list -g $AZURE_RESOURCE_GROUP --query "[].{uri:primaryEndpoints.blob} | [? contains(uri, '$AZURE_STORAGE_ACCOUNT')]" --output tsv)
export AZURE_VNET_NAME=$(az network vnet list --resource-group $AZURE_RESOURCE_GROUP --query "[].{Name:name}" --output tsv) # tail -1 #??
export AZURE_SUBNET_ID=$(az network vnet subnet list --resource-group $AZURE_RESOURCE_GROUP --vnet-name $AZURE_VNET_NAME --query "[].{Id:id} | [? contains(Id, 'worker')]" --output tsv)
export AZURE_NSG_ID=$(az network nsg list --resource-group $AZURE_RESOURCE_GROUP --query "[].{Id:id}" --output tsv)
export INSTANCE_ID=$(oc get nodes -l 'node-role.kubernetes.io/worker' -o jsonpath='{.items[0].spec.providerID}' | sed 's#[^ ]*/##g')

oc process --ignore-unknown-parameters=true -f $L/peer-pod-secret-azure.yaml -p AZURE_CLIENT_ID="${AZURE_CLIENT_ID}" AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET}" AZURE_TENANT_ID="${AZURE_TENANT_ID}" AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}" >peer-pods-secret.json
oc apply -f peer-pods-secret.json
oc get secret peer-pods-secret -o yaml

AZURE_IMAGE_ID=""
oc process --ignore-unknown-parameters=true -f $L/peer-pod-azure-cm-template.yaml -p AZURE_SUBNET_ID=${AZURE_SUBNET_ID} AZURE_NSG_ID=${AZURE_NSG_ID} AZURE_IMAGE_ID=${AZURE_IMAGE_ID} AZURE_REGION="${AZURE_REGION}" AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}" >peer-pods-cm.json
oc apply -f peer-pods-cm.json
oc get cm peer-pods-cm -o json

# Generate SSH keys and create a ssh-key-secret object
ssh-keygen -f ./id_rsa -N "" -y
oc create secret generic ssh-key-secret -n openshift-sandboxed-containers-operator --from-file=id_rsa.pub=./id_rsa.pub --from-file=id_rsa=./id_rsa
