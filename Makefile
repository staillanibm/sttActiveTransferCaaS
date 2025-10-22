DOCKER_RUNTIME=podman

MFT_BASE_IMAGE=default-route-openshift-image-registry.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com/mft/activetransfer:latest
MFT_IMAGE_NAME=default-route-openshift-image-registry.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com/mft/stt-activetransfer
MFT_TAG=1.0.0-mysql

DCC_BASE_IMAGE=default-route-openshift-image-registry.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com/mft/activetransfer-dcc:latest
DCC_IMAGE_NAME=default-route-openshift-image-registry.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com/mft/stt-activetransfer-dcc
DCC_TAG=1.0.0-mysql

KUBERNETES_NAMESPACE=mft

mft-build:
	cd build && $(DOCKER_RUNTIME) build -t $(MFT_IMAGE_NAME):$(MFT_TAG) --platform=linux/amd64 --build-arg BASE_IMAGE=$(MFT_BASE_IMAGE) -f Dockerfile_mft .

dcc-build:
	cd build && $(DOCKER_RUNTIME) build -t $(DCC_IMAGE_NAME):$(DCC_TAG) --platform=linux/amd64 --build-arg BASE_IMAGE=$(DCC_BASE_IMAGE) -f Dockerfile_dcc .

mft-push:
	$(DOCKER_RUNTIME) push $(MFT_IMAGE_NAME):$(MFT_TAG)

dcc-push:
	$(DOCKER_RUNTIME) push $(DCC_IMAGE_NAME):$(DCC_TAG)

dcc-run-job:
	oc apply -f openshift/secrets.yaml -n $(KUBERNETES_NAMESPACE)
	oc apply -f openshift/dcc-job.yaml -n $(KUBERNETES_NAMESPACE)

dcc-delete-job:
	oc delete -f openshift/dcc-job.yaml -n $(KUBERNETES_NAMESPACE)

dcc-logs:
	oc logs -f job/dcc-job -n $(KUBERNETES_NAMESPACE)

mft-deploy:
	oc apply -f openshift/secrets.yaml -n $(KUBERNETES_NAMESPACE)
	oc apply -f openshift/mft-deploy.yaml -n $(KUBERNETES_NAMESPACE)

mft-logs:
	oc logs -f deployment/mft -n $(KUBERNETES_NAMESPACE)

mft-delete:
	oc delete -f openshift/mft-deploy.yaml -n $(KUBERNETES_NAMESPACE)