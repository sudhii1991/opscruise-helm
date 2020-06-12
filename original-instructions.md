# Original Instructions

OpsCruise Installation Readme.txt
Date: 20200512
Build: oc-south-Rel1.1.0-h.tar.gz
-------------------------------------------------------------------------------
Files Includes with Opscruise Installer


You should have received:


1. TAR archive file (e.g., oc-south-Rel1.1.0-h.tar.gz )
2. Environment Variables file(oc-environment.env)

Prerequisites

The following modules should have been installed:
```
1. Kubernetes     V1.11 +
2. cAdvisor       V0.35.0 +               ...deployment chart is provided
3. NodeExporter   node-exporter1.1.0 +    ...deployment chart is provided
4. KSM Exporter   V1.6.0 +                ...deployment chart is provided
5. Prometheus     V2.17.1 +               ...deployment chart is provided
6. Helm           V3 +
```

The following outbound connections must be allowed:

```
<yourname>.opscruise.io:443,9093
auth.opscruise.io:8443
```

Preparation Steps

1. UNTAR ALL TAR FILES

Untar all tar files provided by OpsCruise in the ‘/opt/opscruise/’ directory.

```
mkdir /opt/opscruise/

cp oc-environment.env /opt/opscruise/

tar -xvzf oc-south-Rel1.1.0-h.tar.gz -C /opt/opscruise/ && find /opt/opscruise/ -maxdepth 1 -name "*.tar.gz" -exec tar xvzf {} -C /opt/opscruise/ \;
```

2. CREATE KUBERNETES NAMESPACE AND SECRETS FOR OPSCRUISE GATEWAYS

Follow these steps to create secrets


Usage: 
```
./run.sh --setup-helmchart-env oc-environment.env awsgw|k8sgw|promgw(gateway name)
```

(Note: In case of awsgw, Usage: `./run.sh --setup-helmchart-env oc-environment.env awsgw <AWS_REGION> <AWS_ACCESS_KEY_ID> <AWS_SECRET_ACCESS_KEY>`)


This will create all dependency secrets for OpsCruise gateway

3. DEPLOYMENT OF PROMETHEUS & EXPORTERS

```
cd /opt/opscruise/helmchart/
```

3.1 To deploy Prometheus

```
helm upgrade --install <helm instance name> ./helm-chart-prometheus/ --namespace collectors
```


3.1.1 If prometheus already running 

Add following configuration into the Prometheus config file:

Remote_write:
- url: "http://promgw-service.opscruise.svc.cluster.local:8585/ingest"
       queue_config:
      max_samples_per_send: 120000

Update existing Prometheus helm chart:

```
helm upgrade --install <helm instance name> <prometheus helm chart dir> --namespace collectors
```

3.2 To deploy KSM

```
helm upgrade --install <helm instance name> ./helm-chart-ksm/ --namespace collectors
```

3.3 To deploy cAdvisor

```
helm upgrade --install <helm instance name> ./helm-chart-cadvisor/ --namespace collectors
```

3.4 To deploy Node Exporter 
   
```
helm upgrade --install <helm instance name> ./helm-chart-node-exporter/ --namespace opscruise
```

4. DEPLOYMENT OF OPSCRUISE GATEWAYS

4.1 To deploy K8s Gateway

```
helm  upgrade --install <helm instance name> ./helm-chart-k8sgw/ --namespace opscruise
```

Eg: `helm upgrade --install k8sgw-opscruise ./helm-chart-k8sgw/ --namespace opscruise`

4.2 To deploy AWS Gateway

```
helm  upgrade --install <helm instance name> ./helm-chart-awsgw/ --namespace opscruise
```

Eg: `helm upgrade --install awsgw-opscruise ./helm-chart-k8sgw/ --namespace opscruise`

5.3 To deploy Prom Gateway

```
helm upgrade --install <helm instance name> ./helm-chart-promgw/ --namespace opscruise
```

5. Verify the deployment

5.1 Check deployment in helm

Check helm chart for successful deployments:

```
helm list -A  (which should show the deployments of your running gateways)
```

5.2 Check Kubernetes cluster for deployed gateway:

```
kubectl get pods -n opscruise
```

5.3 Check Kubernetes cluster for deployed collectors

```
kubectl get pods -n collectors
```