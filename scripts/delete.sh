#!/bin/bash

set -u -x

OPENSTACK_SERVICES=$(cat scripts/openstack_services.txt)
THIRD_PARTY_SERVICES=$(cat scripts/third_party_services.txt)
INFRA_SERVICES=$(cat scripts/infra_services.txt)

echo "Deleting infra services"
for service in $INFRA_SERVICES
do
    docker-compose -f services/infra/$service/dev.yml down -v
done

echo "Deleting third party services"
for service in $THIRD_PARTY_SERVICES
do
    docker-compose -f services/third-party/$service/dev.yml down -v
done

echo "Deleting OpenStack services"
for service in $OPENSTACK_SERVICES
do
    docker-compose -f services/openstack/$service/dev.yml down -v
done