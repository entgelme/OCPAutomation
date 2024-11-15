oc apply -f namespace-acm-hub.yml
oc apply -f operatorGroup-acm-hub.yml
oc apply -f subscription-acm-operator.yml 
sleep 30
oc apply -f multiclusterhub-multiclusterhub.yml 
oc get mch -w