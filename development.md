# operator sdk

Installing the SDK
```bash
brew install operator-sdk
```

# python requirements

Aside from the vanilla installation of the operator SDK a few updates/additions to the already installed python packages have been used:

- psycopg2-binary (needed to connect with postgres)
- ansible==2.9.2 (fixed a syntax issue)
- openshift==0.10.1 (newer ansible modules)

This can all be installed using the [requirements.txt](requirements.txt)

```bash
pip3 install -r requirements.txt
```

# building the operator image

Necessary when Ansible code has been changed

```bash
operator-sdk build kabisa/postgresdb-operator
docker push kabisa/postgresdb-operator
```

# rendering the single operator installation yaml

```bash
kubectl create -k deploy --dry-run -o yaml > operator_from_single_file.yaml
```
