FROM quay.io/operator-framework/ansible-operator:v0.11.0
COPY requirements.txt ${HOME}/requirements.txt
USER root
RUN pip3 install -r ${HOME}/requirements.txt
COPY watches.yaml ${HOME}/watches.yaml

COPY roles/ ${HOME}/roles/

# operator-sdk build kabisa/postgresdb-operator
# docker push kabisa/postgresdb-operator
