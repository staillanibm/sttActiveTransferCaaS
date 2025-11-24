# Active Transfer Server deployment in ROKS

##  Image registry setup

By default the image registry isn't exposed to the internet. To make it accessible from your laptop, issue the following command:
```
oc patch configs.imageregistry.operator.openshift.io cluster \
  --type merge -p '{"spec":{"defaultRoute":true}}'
```

After a few seconds, the external route should be active. You can check it with this command:
```
oc get route -n openshift-image-registry
```
It should return something like:
```
NAME              HOST/PORT                                            PATH   SERVICES          PORT   TERMINATION   WILDCARD
default-route     default-route-openshift-image-registry.apps.<cluster-domain>          image-registry   5000   reencrypt     None
```


##  Project creation

Create a project using the following command (you can call it whatever you want, I call it "mft" here):
```
oc new-project mft
```

By default you're placed within this project / namespace. So in the oc commands that follow I do not mention the namespace.


##  Image registry service account and secret

For the sake of convenience we create a service account that has both push and pull privileges. Therefore we can also use it to push images from our laptop to the OCP registry.

Note: this service account only has push and pull privileges in the project / namespace where you issue these commands.  

```
oc create sa registry-sa

oc adm policy add-role-to-user system:image-builder -z registry-sa
oc adm policy add-cluster-role-to-user system:image-puller -z registry-sa

REGISTRY_URL=$(oc get route -n openshift-image-registry default-route -o jsonpath='{.spec.host}{"\n"}')
REGISTRY_TOKEN=$(oc create token registry-sa --duration=2160h)

oc create secret docker-registry regcred \
  --docker-server=${REGISTRY_URL} \
  --docker-username=registry-sa \
  --docker-password=${REGISTRY_TOKEN} \
  --docker-email=none
```

To perform the docker login on your laptop:
```
docker login ${REGISTRY_URL} -u registry-sa -p ${REGISTRY_TOKEN}
```


##  Product images in the registry

We assume here that two image streams exist in the project:
- One that contains the database configurator images
- One that contains the active transfer images

### Database configurator

Except if you need to use specific JDBC drivers, you don't need to create a custom image. By default the configuration of the databases is carried out using the embedded DataDirect driver.  
In what follows I work with an image stream called activetransfer-dcc.

### Active Transfer server

Unlike the database configurator, it's more common to work with a custom image. You'll usually attach a few custom integration packages and utilitarian packages to the official product image.
In what follows I work with an image stream called stt-activetransfer.


##  Active transfer initialisation

Before deploying Active Transfer Server for the first time, you need to initialize its databases. We have two database: the live database and the one used for archiving.  
The database configurator is in charge of this initialization, and since this is a one-off task we run it using a Kubernetes job.  
This job is configured using a secret named dcc-secret, which simply holds the JDBC properties to connect to the two databases
- dbType: a code telling the database configurator which database we target (pgsql, mysql, ...)
- dbUrl, dbUser, dbPassword: JDBC url and credentials for the live database
- dbArchUrl, dbArchUser, dbArchPassword: JDBC url and credentials for the archive database

### Databases creation

You need to create the databases in the target RDBMS and ensure the users you will use for JDBC connectivity have the ability to create assets (tables, indices, ...)

### JDBC url syntax

jdbc:wm:${DB_TYPE}://${DB_SERVER}:${DB_PORT};DatabaseName=${DB_NAME};

DB_TYPE: oracle, db2, mysql, postgresql, sqlserver, sybase
DN_NAME: the name of the database you've created (you'll therefore have one for the live DB, and one for the archive DB)

### TLS

If the target databases need to be acced with TLS, append these properties to the JDBC url:
```
  EncryptionMethod=SSL;
  ValidateServerCertificate=true;
```

### Managing private certification authorities

If the database server presents a certificate signed by a private certification authority, then you need to configure the database configurator to trust this certificate.

Start by adding these properties to the JDBC url:
```
  HostNameInCertificate=${DB_SERVER};
  TrustStore=/certs/db-truststore.jks;
  TrustStorePassword=${TRUSTSTORE_PASSWORD}
```
