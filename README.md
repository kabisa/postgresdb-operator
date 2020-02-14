# postgresdb-operator

This is an operator built with [Operator Framework](https://github.com/operator-framework/operator-sdk) Ansible. [Guide](https://github.com/operator-framework/operator-sdk/blob/master/doc/ansible/user-guide.md).
Its goal is to manage database resources with `kubectl` within a Postgres deployment. Specifically to allow databases to be deployed from pipeline and set up users, grants and backups etc.
It expects Postgres to be running already.

What does/can it manage:
 - database creation / deletion `Database`
 - postgres users `PostgresUser`
 - postgres user grants `PostgresUserGrant`
 - database backups (to azure blobs) `DatabaseBackupJob`
 - database restores (from azure blobs) `DatabaseRestoreJob`
 - database copies (as long as the versions are compatible)
 
What is required:
 - a kubernetes cluster
 - a running postgres database (not necessarily inside the cluster)
 - postgres credentials that can create and drop databases
 - for backups to azure blobs: a service principal that has write access to azure blobs
 - for restores from azure blobs: a service principal that has read access to azure blobs

 
## Important notes

 - The operator handles out-of-order creation of resources fairly well. But editing kubernetes `Secrets` wont retrigger the operator to run.
That's why it is advisable to first create `Secrets` and create the depending resources afterwards.
 - In resource definitions like that of `Database` or `DatabaseUser` the are two name fields. That of the resource definition / Kubernetes object (metadata->name) and that of the managed object itself. Eg. `database_name` and `user_name`. The resource names are used to refer to the Kubernetes object. For example if you give a grant to a `DatabaseUser` you give the name of the Kubernetes object, not the name of postgres user in the database. 
 - Operations by the operator (backup jobs, restore jobs and copy jobs) have been implemented as a 2-stage process. The first part will be performed by an [initContainer](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) the second part will be performed by the "main" container. This means when you want to see the logs of such a container you will have to know the name of the `initContainer`

## Installation

The operator can be installed as bundle (requires kubectl version >= 1.15 ) for this we use the relatively new feature [Kustomize](https://kustomize.io/) that allows us to do `kubectl create -k`. You can inspect the [kustomization.yml](deploy/kustomization.yml) and see that all Custom Resource Definitions resources are included there.
There's also the option to install straight from a single `kubctl create` however that can only be used to install into the `default` namespace

### straight from the interwebs

```bash
kubectl create -f https://raw.githubusercontent.com/kabisa/postgresdb-operator/backups/deploy/operator_from_single_file.yaml
```

### Kustomized

First you will need to clone this repository and cd into the cloned directory.

```bash
kubectl create -k deploy
```

Or to a different namespace

```bash
kubectl create -k deploy -n postgres
``` 

## Usage

All of the definitions presented here are also available in the folder [deploy/examples](deploy/examples). The example yamls are numbered so that you can follow the "tutorial" easier.
You can edit them and use `kubectl create -f <filename>` to use them in your cluster. 
Do note that if you've installed the operator to a separate namespace you will have to extend the metadata as follows:

```yaml
metadata:
  name: something
  namespace: <your namespace here>
```

If you want to tail the logs of the operator you can do so as follows:

```bash
kubectl logs -f <postgresdb-operator-pod-name> -n <namespace> -c ansible
```

Let's get our hands dirty...
First we need access to the Postgres instance. We'll put a password in a secret and describe our Postgres host

Our password:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres
data:
  password: cG9zdGdyZXNxbFBhc3N3b3Jk  # postgresqlPassword (plz do not use this pw in production)
```

Our Postgres host:
```yaml
apiVersion: postgres.kabisa.nl/v1alpha1
kind: PostgresHost
metadata:
  name: example-host
spec:
  address: "postgres"
  port: 5432
  user_name: "postgres"
  secret_name: "postgres"
  # secret_key: "defaults_to_password"  # change this if you want to use a different key in your secret yaml
```

Now we can create a Database on our Postgres host

```yaml
apiVersion: postgres.kabisa.nl/v1alpha1
kind: Database
metadata:
  name: example-database
spec:
  host: example-host
  database_name: example-database
  drop_on_deletion: true
```

This will log in to the postgres server and create a database with the name `example-database`

## User Management 

Lets create a user for our `example-database`

First our password:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: web-user-secret
data:
  password: cG9zdGdyZXNxbFBhc3N3b3Jk  # postgresqlPassword (plz do not use this pw in production)
```

The user itself
```yaml
apiVersion: postgres.kabisa.nl/v1alpha1
kind: PostgresUser
metadata:
  name: web-user
spec:
  user_name: web
  secret_name: web-user-secret
```

Lets grant the user access to the example database

```yaml
apiVersion: postgres.kabisa.nl/v1alpha1
kind: PostgresUserGrant
metadata:
  name: web-user-grant
spec:
  user_name: web-user
  database_name: example-database
  priv: ALL
```

The priv field borrows its functionality from the [Ansible postgresql user module](https://docs.ansible.com/ansible/latest/modules/postgresql_user_module.html).

> Slash-separated PostgreSQL privileges string: priv1/priv2, where privileges can be defined for database ( allowed options - 'CREATE', 'CONNECT', 'TEMPORARY', 'TEMP', 'ALL'. For example CONNECT ) or for table ( allowed options - 'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER', 'ALL'. For example table:SELECT ). Mixed example of this string: CONNECT/CREATE/table1:SELECT/table2:INSERT.


## Backups and Restores

Lets first set up our Azure Blobs access
```yaml
apiVersion: postgres.kabisa.nl/v1alpha1
kind: AzBlobsContainer
metadata:
  name: pgdumps-daily
spec:
  tenant_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx   # find this in your azure console
  storage_account: backups
  storage_container: pgdumps-daily
```

Currently we only support Service Principals
```yaml
apiVersion: postgres.kabisa.nl/v1alpha1
kind: AzBlobsUser
metadata:
  name: blobsuser
spec:
  user_name: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx
  secret_name: blobs-user-secret
```

A secret to store the password in. 
```yaml
# It is no problem to create this secret only now. 
# The creation of  `AzBlobsContainer` and `AzBlobsUser` does not trigger any operator action.
apiVersion: v1
kind: Secret
metadata:
  name: blobs-user-secret
data:
  password: somebase64encodedpassword
```

Then we can create a backup job
```yaml
apiVersion: postgres.kabisa.nl/v1alpha1
kind: DatabaseBackupJob
metadata:
  name: my-first-backup-job
spec:
  database_name: example-database
  az_blobs_container: pgdumps-daily
  az_blobs_user: blobsuser
```

You should now see a Kubernetes Job in your cluster

```bash
kubectl get jobs
```

```bash
NAME                                  COMPLETIONS   DURATION   AGE
my-first-backup-job-mtu3otuxndg2ma   1/1           27s        3h49m
```

And a pod that performed the job
```bash
kubectl get pods
```

```bash
NAME                                        READY   STATUS      RESTARTS   AGE
my-first-backup-job-mtu3otuxndg2ma-lfscw   0/1     Completed   0          3h50m
```

In case something goes wrong you can see the logs as follows:

- The backup container:
```bash
kubectl logs <pod name> -n <your namespace> -c pg-backup
```
- The upload container (specifying the container name is optional):
```bash
kubectl logs <pod name> -n <your namespace> [ -c az-blobs-upload ]
```

And also a restore job

```yaml
apiVersion: postgres.kabisa.nl/v1alpha1
kind: DatabaseRestoreJob
metadata:
  name: my-first-restore-job
spec:
  database_name: example-database
  az_blobs_container: pgdumps-daily
  az_blobs_user: blobsuser
  file_name: file-name-in-az-blobs.dump 
```

Checking the logs for the restore job

- The download container:
```bash
kubectl logs <pod name> -n <your namespace> -c az-blobs-download
```

- The restore container (specifying the container name is optional):
```bash
kubectl logs <pod name> -n <your namespace> -c pg-restore
```

### CronJob

The operator allows you to create cron jobs in the same way as making a backup job. 
The only difference is that you now need a `cron_interval` definition
```yaml
apiVersion: postgres.kabisa.nl/v1alpha1
kind: DatabaseBackupCronJob
metadata:
  name: my-first-backup-cronjob
spec:
  database_name: example-database
  az_blobs_container: pgdumps-daily
  az_blobs_user: blobsuser
  cron_interval: "9 1 * * *"
```
