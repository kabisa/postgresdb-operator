# postgresdb-operator

This is an operator build with Operator Framework Ansible. Its goal is to manage database resources within a Postgres deployment. It expects Postgres to be running already.

What does it manage:
 - database creation
 - database deletion
 
What is required:
 - a secret that contains the Postgres admin password 
 - a PostgresHost definition
 
## Installation

 - as a bundle use `kubectl create -k deploy` (requires kubectl version >= 1.15 )

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
