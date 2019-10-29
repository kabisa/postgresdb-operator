#!/usr/bin/env bash
# for development purposes
operator-sdk build kabisa/postgresdb-operator
docker push kabisa/postgresdb-operator
sleep 2
export operator=`kubectl get pods | grep postgresdb-operator | awk '{print $1}'`
kubectl delete pod $operator
