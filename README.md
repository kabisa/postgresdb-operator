# postgresdb-operator

This is an operator built with [Operator Framework](https://github.com/operator-framework/operator-sdk) Ansible. [Guide](https://github.com/operator-framework/operator-sdk/blob/master/doc/ansible/user-guide.md)
Its goal is to manage database resources with `kubectl` within a Postgres deployment. Specifically to allow databases to be deployed from pipeline and set up users, grants and backups etc.
It expects Postgres to be running already.

What does/can it manage:
 - database creation
 - database deletion
 - postgres users
 - postgres user grants
 - database backups (to azure blobs)
 - database restores (from azure blobs)
 - database copies (as long as the versions are compatible)
 
What is required:
 - a PostgresHost definition (make sure the user has rights to create and delete databases)
 - a secret that contains the Postgres admin password 
 - a kubernetes cluster ;)
 
## Installation

The operator can be installed as bundle (requires kubectl version >= 1.15 )

```bash
kubectl create -k deploy
```

Or to a different namespace

```bash
kubectl create -k deploy -n postgres
``` 

## Usage

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
  tenant_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx
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

A secret to store the password in
```yaml
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
