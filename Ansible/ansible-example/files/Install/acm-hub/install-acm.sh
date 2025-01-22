oc apply -f namespace-acm-hub.yml
oc apply -f operatorGroup-acm-hub.yml
oc apply -f subscription-acm-operator.yml 
sleep 30
oc apply -f multiclusterhub-multiclusterhub.yml 
oc get mch -w

# gitops integration
oc apply -f clusterrole-openshift-gitops-policy-admin.yml 
oc apply -f clusterrolebinding-openshift-gitops-argocd-application-controller.yml 
oc apply -f ../acm-gitops/namespace-rhacm-policies.yml 

# Berechtigung für workshop-admin user
#oc patch clusterrolebinding.rbac open-cluster-management:subscription-admin -p '{"subjects": [{"apiGroup":"rbac.authorization.k8s.io", "kind":"User", "name":"workshop-admin"}]}'
