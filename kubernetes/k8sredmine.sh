#!/bin/bash

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        v="${1/--/}"
        declare $v="$2"
   fi

  shift
done

# Create
if [ -z create ] || [ -v create ] || [ "$create" == "conduit" ] || [ "$create" == "istio" ]; then
  kubectl create namespace redmine

  tr --delete '\n' <redmine.postgres.password.txt >.strippedpassword.txt && mv .strippedpassword.txt redmine.postgres.password.txt
  tr --delete '\n' <redmine.imap.password.txt >.imap.strippedpassword.txt && mv .imap.strippedpassword.txt redmine.imap.password.txt
  tr --delete '\n' <redmine.smtp.password.txt >.smtp.strippedpassword.txt && mv .smtp.strippedpassword.txt redmine.smtp.password.txt
  kubectl create secret -n redmine generic redmine-postgres-pass --from-file=redmine.postgres.password.txt
  kubectl create secret -n redmine generic redmine-imap-pass --from-file=redmine.imap.password.txt
  kubectl create secret -n redmine generic redmine-smtp-pass --from-file=redmine.smtp.password.txt

  kubectl apply -f ./local-volumes.yaml
fi

if [ -z create ] ; then
  kubectl apply -n redmine -f ./redmine-deployment.yaml

  kubectl get svc redmine -n redmine
elif [ -v create ] && [ "$create" == "conduit" ]; then
  cat ./redmine-deployment.yaml | conduit inject --skip-outbound-ports=5432,11211 --skip-inbound-ports=5432,11211 - | kubectl apply -n redmine -f -

  kubectl get svc redmine -n redmine -o jsonpath="{.status.loadBalancer.ingress[0].*}"

  kubectl get svc redmine -n redmine
elif [ -v create ] && [ "$create" == "istio" ]; then
  kubectl label namespace redmine istio-injection=enabled

  kubectl apply -n redmine -f ./redmine-deployment.yaml
  kubectl apply -n redmine -f ./redmine-ingress.yaml

  export GATEWAY_URL=$(kubectl get po -l istio=ingress -n istio-system -o 'jsonpath={.items[0].status.hostIP}'):$(kubectl get svc istio-ingress -n istio-system -o 'jsonpath={.spec.ports[0].nodePort}')

  printf "Istio Gateway: $GATEWAY_URL"
fi


# Delete
if [ -z delete ] || [ "$delete" == "conduit" ]; then
  kubectl delete -f ./local-volumes.yaml
  kubectl delete secret -n redmine redmine-postgres-pass
  kubectl delete secret -n redmine redmine-imap-pass
  kubectl delete secret -n redmine redmine-smtp-pass
  kubectl delete -n redmine -f ./redmine-deployment.yaml

  kubectl delete namespace redmine
fi

if [ -v delete ] && [ "$delete" == "istio" ]; then
  kubectl delete -f ./local-volumes.yaml
  kubectl delete secret -n redmine redmine-postgres-pass
  kubectl delete secret -n redmine redmine-imap-pass
  kubectl delete secret -n redmine redmine-smtp-pass
  kubectl delete -n redmine -f ./redmine-deployment.yaml
  kubectl delete -n redmine -f ./redmine-ingress.yaml

  kubectl delete namespace redmine
fi