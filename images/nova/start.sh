#!/bin/bash

set -u

export PGPASSWORD=secret

echo "DB configuration"
psql -h openstack_postgresql -p 5432 -v ON_ERROR_STOP=1 --username "admin" <<-EOSQL
    CREATE USER nova;
    ALTER USER nova WITH PASSWORD 'secret';
    CREATE DATABASE nova;
    CREATE DATABASE nova_api;
    CREATE DATABASE nova_cell0;
    GRANT ALL PRIVILEGES ON DATABASE nova TO nova;
    GRANT ALL PRIVILEGES ON DATABASE nova_api TO nova;
    GRANT ALL PRIVILEGES ON DATABASE nova_cell0 TO nova;
EOSQL

echo "Syncing api database"
nova-manage api_db sync

echo "Registering cell0 database"
nova-manage cell_v2 map_cell0

echo "Create cell1 cell"
nova-manage cell_v2 create_cell --name=cell1 --verbose

echo "Syncing nova database"
nova-manage db sync

echo "Verify cell0 and cell1 are registered"
nova-manage cell_v2 list_cells

source /opt/osrc-v3

echo "Creating user"
if [ -z `openstack user list -f csv -q |grep nova` ]
then
    openstack user create --domain Default --password secret nova
else
    echo "Skipping"
fi

echo "Adding to role admin"
openstack role add --project service --user nova admin

echo "Creating nova service"
if [ -z `openstack service list -f csv -q |grep nova` ]
then
    openstack service create --name nova --description "OpenStack Compute" compute
else
    echo "Skipping"
fi

endpoint=`openstack endpoint list -f csv -q |grep nova`
if [ -z "$endpoint" ]
then
    echo "Creating public endpoint"
    openstack endpoint create --region RegionOne compute public http://0.0.0.0:8774/v2.1

    echo "Creating internal endpoint"
    openstack endpoint create --region RegionOne compute internal http://0.0.0.0:8774/v2.1

    echo "Creating admin endpoint"
    openstack endpoint create --region RegionOne compute admin http://0.0.0.0:8774/v2.1
else
    echo "Skipping"
fi

echo "Creating placement service"
if [ -z `openstack user list -f csv -q |grep placement` ]
then
    openstack user create --domain Default --password secret placement
else
    echo "Skipping"
fi

echo "Adding to role admin"
openstack role add --project service --user placement admin

echo "Creating nova placement service"
if [ -z `openstack service list -f csv -q |grep placement` ]
then
    openstack service create --name placement --description "Placement API" placement
else
    echo "Skipping"
fi

endpoint=`openstack endpoint list -f csv -q |grep placement`
if [ -z "$endpoint" ]
then
    echo "Creating public endpoint"
    openstack endpoint create --region RegionOne placement public http://0.0.0.0:8778/v2.1

    echo "Creating internal endpoint"
    openstack endpoint create --region RegionOne placement internal http://0.0.0.0:8778/v2.1

    echo "Creating admin endpoint"
    openstack endpoint create --region RegionOne placement admin http://0.0.0.0:8778/v2.1
else
    echo "Skipping"
fi

echo "Running the api's"
nova-api &
nova-consoleauth &
nova-scheduler &
nova-conductor &
nova-novncproxy