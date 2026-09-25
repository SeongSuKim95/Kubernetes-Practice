<!--
  English publish copy. Image paths use GitHub raw URLs. GFM Markdown (no HTML centering wrappers).
  Diagram SVGs point to images/articles/03/en/.
  Korean publish original: 03-pod-and-workload-management.publish.md
  Image repository: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap03. Pods and Workload Management

> This is the third article in a 15-week series. We look at Pods, the minimum unit in which Kubernetes runs containers, and at Deployments, StatefulSets, and DaemonSets, which manage Pods according to application requirements. We also cover ConfigMaps and Secrets, which separate runtime configuration from container images.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/01-k8s-logo.svg)

In the previous article, we described Kubernetes not simply as a tool that places containers on multiple servers, but as a platform that continuously maintains an application's desired state. Users do not specify every command for creating containers or responding to failures. Instead, they declare the state in which the application should remain, and Kubernetes takes responsibility for bringing actual state in line with that declaration.

This declarative approach values continuously maintaining state over the success of a single command. When a running container disappears, or the actual number of containers differs from the desired number, Kubernetes does not treat the change only as a failed command. It sees a difference between desired and actual state, then repeatedly runs control loops to bring actual state back into alignment. The design aims to preserve declared state over time rather than execute an automation once and stop.

The same philosophy explains why Kubernetes components observe shared state recorded in the API instead of issuing execution commands directly to one another. Each component observes the state changes for which it is responsible and performs work to reconcile actual state. If one component stops temporarily, desired state remains in the API, so the component can resume reconciliation when it starts again. Organizing the system around state reduces coupling between components and lets the platform continue responding to failures and changes.

This article shows how that philosophy appears in application execution units and workload management. Kubernetes groups containers that must run together into Pods and manages Pod sets with Deployments, StatefulSets, or DaemonSets according to application requirements. It can also separate ordinary settings into ConfigMaps and sensitive values into Secrets so the same container image can be used across environments. We begin by distinguishing a manifest, where a user writes desired state, from a resource, which Kubernetes continuously manages.

## 1. Resources and Manifests

The declarative approach from Chapter 2 leaves desired state in the API, and Kubernetes continuously aligns actual state with it. First, two things must be distinguished: where a user writes desired state, and what Kubernetes stores and manages as that state.

If you do not distinguish a YAML file written by a user from an object managed inside a cluster, it is easy to call both of them resources or assume that editing a local file immediately changes a running application. Kubernetes control processes observe objects stored by the API Server, not YAML files on a user's machine. We therefore need to separate the manifest submitted to the API from the resource stored by the API and managed by Kubernetes.

![Relationship between a Kubernetes resource and a manifest](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/01-resource-manifest.svg)

A **manifest** is a declaration of which resource you want and the state in which you want it. Manifests are commonly written in YAML, although JSON is also supported. YAML names the file format used to express the content; manifest names the role of the declaration submitted to the Kubernetes API.

A **resource** is an object that the Kubernetes API stores and manages after a manifest is submitted. A resource may have a `spec`, the desired state declared by the user, and a `status`, the current state observed by Kubernetes. Control processes observe resources stored in the API rather than local manifest files, then perform the work required to make each resource's `spec` real.

In short, a manifest is input sent to the API, while a resource is the object continuously managed in the cluster. One manifest file may contain declarations for multiple resources, and multiple manifest files may collectively express the operating state of one application.

Most manifests repeatedly use four fields. `apiVersion` identifies the API version, and `kind` identifies the resource type. `metadata` contains the resource name and classification information. `spec` contains the desired state. After creating a resource, Kubernetes records actual state in `status`; users rarely write `status` directly in a manifest.

```yaml
# Common structure of a Kubernetes manifest
apiVersion: <API group and version>
kind: <resource kind>
metadata:
  name: <resource name>
spec:
  <desired state>
```

### 1.1 Why Manage Desired State with Manifests

With manifests, operational configuration does not survive only as one-off commands entered in a terminal. The file records which resources are required and the state in which each resource should remain. Submitting the same manifest in another environment requests the same desired state again, reducing manual configuration that depends on an operator's memory.

Because manifests are files, they can be versioned in Git. A team can review manifest changes like application code and trace who changed which setting. If a problem occurs, an earlier manifest version also provides a baseline that can be submitted again to request the previous desired state.

Manifests can also serve as automation input. A deployment pipeline can submit a reviewed file to the Kubernetes API without a person reconstructing the same commands each time.

Here, **kubectl** is a command-line client that sends user commands and manifests to the Kubernetes API. kubectl does not run Pods or containers itself; it sends the desired state represented by a manifest to the API. Kubernetes control processes then observe the stored change and align actual state with desired state.

A local manifest file and an API resource are not automatically linked. After editing the file, you must submit the manifest again with `kubectl apply`, or use a separate synchronization process such as a GitOps tool that detects file changes and submits them, before the cluster resource changes.

### 1.2 Submitting a Manifest with kubectl apply -f

![Flow of submitting a manifest with kubectl apply](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/02-kubectl-apply.svg)

You normally run `kubectl apply -f` in a terminal on a developer machine or CI server where kubectl and cluster access configuration are available. You do not need to log in to a Worker Node and run the command there. The machine running kubectl only needs network access to the API Server.

`apply` is the subcommand that asks Kubernetes to apply manifest configuration to resources. `-f` is short for `--filename` and accepts the path to the manifest to apply. In the command below, `./app.yaml` is a local file resolved from the terminal's current directory. You may also provide an absolute path, a directory containing manifests, or a URL. In other words, `-f` selects the manifest to read, while the current kubeconfig context selects the cluster to which the manifest is submitted.

```bash
# Submit a manifest in the current directory to the selected Kubernetes cluster
kubectl apply -f ./app.yaml
```

When you run the command, kubectl first reads the manifest in `app.yaml`. It then checks **kubeconfig** (the configuration that tells kubectl which cluster to contact and which user credentials to use) for the current API Server address and credentials. kubectl converts the manifest into an API request and sends that request to the selected API Server over the network.

The API Server checks the requesting user's identity and permissions, then validates the manifest fields against the API schema. If the request is valid, the API Server creates the resource when it does not exist or applies the manifest changes to the existing resource. Kubernetes determines whether it is the same resource from identifying information that includes resource kind and name.

When the API Server stores the resource, that does not mean kubectl has directly run a container on a Worker Node. After the resource is stored, control processes observe the resource change and reduce the difference between the desired state in `spec` and actual state. Results such as `created`, `configured`, and `unchanged` therefore report how the API resource was applied; they do not mean the application is fully ready to run.

We can now look at the Kubernetes resources that express declarations from manifests. We start with the Pod, the minimum unit in which containers actually run, then expand to workload resources that manage Pod sets for different purposes.

## 2. Pods: Running Containers Together

![Official Kubernetes Pod resource mark](https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/pod.svg)

### 2.1 Kubernetes' Minimum Execution Unit

![Kubernetes Pod](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/04-pod.svg)

A **Pod** is the minimum execution unit that Kubernetes creates and places on a Worker Node. Kubernetes does not place each container independently. The **Scheduler** is a control process that selects a suitable Worker Node for a Pod that does not yet have a Node. After the Scheduler selects a Worker Node, the **Kubelet** running on that Node starts the containers declared in the Pod. The Kubelet is an agent that observes Pods assigned to its Node and manages their containers so they run in the declared state. The boundary Kubernetes places and replaces is the Pod, not an individual container.

A Pod can contain one or more containers. The most common arrangement has one application container. Even with a single container, Kubernetes can consistently manage placement, networking, storage, and lifecycle through the Pod.

The ability to include multiple containers exists for processes that must cooperate closely as one execution unit. Containers belong in the same Pod when they must be placed together, share networking or files, and be cleaned up together when the Pod disappears. A Pod is therefore not merely a container wrapper. It defines which containers Kubernetes manages as one application execution unit.

![Learn Kubernetes with Seongsu: Pod character](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-pod.png)

The Pod character carries **Containers** in a front pouch like a kangaroo. The hexagon and cube marks suggest Kubernetes' minimum execution unit, while the two containers in the pouch show that one Pod can contain multiple containers.

All containers in one Pod are always placed on the same Worker Node. They share the Pod lifecycle boundary: the Pod is created, placed on a Node, and deleted as a unit. Sharing that lifecycle boundary does not mean every container always restarts at the same time. If one container exits, the Kubelet may keep the Pod and restart only that container according to the configured restart policy.

Networking is shared at the Pod level. Containers in the same Pod share one Pod IP and port space. Each container must use different ports, and a process in one container can reach a process in another through `localhost`. This shared network is also why callers reach processes through the Pod IP rather than locating an individual container directly.

Storage can also be shared within a Pod. A **volume** connects storage space for containers to a Pod. If a volume is declared once in the Pod and mounted into multiple containers at their own paths, those containers can read and write the same files. Their root filesystems are not merged; only the mounted volume paths are shared.

Because of these shared boundaries, unrelated applications should not be combined in one Pod. Applications with different release schedules and scaling criteria, such as a web server and a database, should use separate Pods. Put containers in the same Pod only when they must be placed and deleted together and must closely share networking or files.

### 2.2 The Sidecar Pattern

![Sidecar collecting application logs](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/05-sidecar-logging.svg)

The **sidecar pattern** is a common use of a Pod's shared boundaries. It places a helper container beside the container that runs the application's primary function. Sidecars are useful for functions such as log collection, proxying, or configuration refresh that need to share the application's execution environment.

For example, an application container can write logs to a file while a log collection container reads that file and sends it to external storage. Because both containers are placed in the same Pod and mount the same log volume, they can share log files without a separate network file share. The following manifest shows that arrangement.

```yaml
# Two containers in one Pod sharing a temporary volume
apiVersion: v1
kind: Pod
metadata:
  name: api-server
spec:
  containers:
  - name: api
    image: my-api:1.0
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
  - name: log-agent
    image: fluentd:v1.18
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
  volumes:
  - name: app-logs
    emptyDir: {}
```

In this manifest, both containers mount the same volume, `app-logs`, at their own `/var/log/app` paths.

A Pod is a replaceable execution unit. A Pod already placed on one Worker Node does not move to another Node. When Kubernetes needs to replace it, Kubernetes creates a Pod with a new name and IP. If you delete a standalone Pod, Kubernetes does not automatically create the same Pod again. Long-running applications therefore need a higher-level resource that manages the number of Pod replicas and the Pod replacement process.

The correct higher-level resource depends on why the Pods must be maintained. Use a Deployment when interchangeable Pods, such as web API Pods, must remain at a desired count. Use a StatefulSet when each Pod needs a stable name and storage. Use a DaemonSet when each Node must provide a local function. All three resources use Pod templates, but they differ in which Pod set they treat as desired state. We examine these three cases in order.

## 3. Deployments: Managing Pod Replicas and Rollouts

![Official Kubernetes Deployment resource mark](https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/deploy.svg)

![Kubernetes Deployment](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/06-deployment.svg)

A Pod is the minimum unit in which an application runs, but Kubernetes operations generally do not aim to preserve one Pod's name and IP forever. A Pod may disappear during a failure or rollout and be replaced by a Pod with a new name and IP. Operations must preserve the state of a set of Pods performing the same role, not the identity of one particular Pod.

A **Deployment** is a higher-level resource that declares and maintains desired state for that Pod set. Users declare which Pod configuration to maintain, how many Pods to keep, and how to replace the Pod configuration. A Deployment continually checks the difference between the current and desired Pod sets, then creates required Pods or reduces excess Pods to reconcile that difference. This is the declarative approach and control loop from Chapter 2 applied to application delivery.

### 3.1 Declaring a Deployment with a Manifest

A **Label** is key-value classification information attached to a Kubernetes resource. A **Selector** identifies managed resources by Label conditions. A Deployment manifest declares both the number of Pods to maintain and the common configuration to apply to new Pods. `replicas` specifies the Pod count, while `template` contains settings such as the container image and port. `selector` specifies the Label condition used to find managed Pods, and the Pod template must attach the same Label.

```yaml
# Deployment declaring three Pod replicas and a Pod template
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: my-web:1.0
        ports:
        - containerPort: 8080
```

This manifest declares that three Pods with Label `app: web` must be maintained. `spec.template` contains the common configuration the Deployment uses to create a new Pod. `spec.selector.matchLabels` is the criterion for finding Pods created from that configuration. The Selector and Pod template Label must therefore match.

Here, a **replica** means one independent Pod created from the same Pod template. `replicas: 3` does not run three containers inside one Pod; it maintains three Pods that perform the same role. Each Pod has a different name and IP, and each can be replaced independently when a failure occurs or deployment configuration changes. Replica describes a Pod's role; there is no separate resource kind named `Replica Pod`.

Internally, a Deployment creates and manages a **ReplicaSet**, a resource that maintains the number of Pod replicas matching a Label condition. The Deployment manages the Pod template and rollout process, while the ReplicaSet counts Pods that match its Selector and aligns that count with the desired number of replicas. When too few Pods exist, the ReplicaSet creates Pod objects. When too many exist, it removes the excess Pods.

The relationship proceeds from Deployment to ReplicaSet to Pod. Users normally change the Deployment's `replicas` and Pod template, and the Deployment manages ReplicaSets that match that declaration. Directly changing the replica count of a ReplicaSet managed by a Deployment can conflict with the state declared by the Deployment. It is therefore safer to change a deployed application's replica count and Pod template through the Deployment.

A ReplicaSet creates Pod objects and maintains the Pod replica count, but it does not decide which Worker Node will run each Pod. The Scheduler examines each Pod without an assigned Node and selects the Worker Node on which that Pod will run.

![Deployment selecting a Pod set with Labels and a Selector](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/07-deployment-selector.svg)

Because Pod names and IPs can change, a Deployment does not use those values to identify its Pod set. The Deployment treats Pods matching the Selector's Label condition as its managed set. It also attaches the same Label through the Pod template so a newly created Pod joins the same set.

Labels and Selectors let a Deployment continuously manage a Pod set without knowing exact Pod names in advance. If `app: web` is the management criterion, a newly created Pod remains a web application replica when it has that Label, even after an old Pod disappears. If three replicas are desired but only two matching Pods exist, the ReplicaSet creates one Pod. If four exist, it removes one. Desired state is restored by creating a new Pod for the same role, not by reviving the deleted Pod itself.

A Deployment does not store a fixed list of individual Pods; it declares the managed Pod set through a Label condition. This design also reflects the Kubernetes model in which resources are loosely connected through shared API state.

A Deployment maintains more than the number of Pod replicas. When the Pod configuration changes, such as a container image update, the Deployment gradually replaces the old Pod set with a new one and manages the transition so usable Pods remain available during the rollout. The core purpose of a Deployment is therefore not to create Pods once, but to continuously manage the count, configuration, and change process of a Pod set as desired state.

![Learn Kubernetes with Seongsu: Deployment character](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-deployment.png)

The Deployment character watches several **Pods** like an operator with a hard hat and checklist. The identical Pods and the act of caring for a failed Pod illustrate how a Deployment continuously manages the desired Pod replica count and rollout state.

### 3.2 ReplicaSets and Rollout Changes

A Deployment does not maintain Pods one by one directly. The Deployment creates a **ReplicaSet**, and the ReplicaSet maintains the specified number of Pod replicas. If the Deployment manifest says `replicas: 3`, the ReplicaSet aligns state so that three Pods using the same template are running.

![Deployment replacing a Pod template through ReplicaSets](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/08-deployment-replicaset-update.svg)

One ReplicaSet represents a Pod template at a particular point in time. When a Deployment's container image changes from `my-web:1.0` to `my-web:1.1`, the Deployment does not modify existing Pods in place. It creates a ReplicaSet with the new Pod template. The Deployment reduces the old ReplicaSet's Pod replica count while increasing the new ReplicaSet's count, gradually replacing Pods. This process is called a **rolling update**. If the previous ReplicaSet's rollout history remains available, the Deployment can also roll back to an earlier Pod template.

A ReplicaSet creating a new Pod to replace a missing Pod and a Kubelet restarting an exited container are separate control actions.

## 4. StatefulSets: Preserving Pod Identity for Stateful Applications

![Deployment and StatefulSet use cases](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/09-deployment-vs-statefulset-scenarios.svg)

Deployment Pods are assumed to perform the same role and be interchangeable. If one web server Pod disappears, a new Pod from the same template can replace it, and clients do not need to distinguish which Pod handles a request. Not every application can operate this way.

A **StatefulSet** is a workload resource for stateful applications whose Pods require distinct identities. Pods created by a StatefulSet receive ordered names such as `database-0` and `database-1`. A replacement Pod reuses the same ordinal name, allowing the application to distinguish each instance.

A StatefulSet is also used to connect a different persistent volume to each Pod. If `database-0` is replaced, the existing volume for `database-0` can be reattached to the newly created `database-0` Pod. The Pod changes, but the relationship between that Pod's role and its data store continues.

By default, a StatefulSet creates and terminates Pods in order and proceeds to the next Pod after the earlier ordinal is ready. This behavior is useful for databases and message brokers that need startup ordering or stable network identity between instances.

To provide stable network names for individual Pods, you also prepare a **Headless Service** connected to the StatefulSet. Instead of proxying requests through one virtual IP, a Headless Service makes the network address of each StatefulSet Pod discoverable through DNS, the system that resolves names to network addresses. In the following manifest, `serviceName: database` identifies the Headless Service connected to the StatefulSet.

```yaml
# StatefulSet managing three distinct Pod identities
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: database
        image: my-database:1.0
```

A StatefulSet does not automatically configure database replication or failover. Kubernetes preserves each Pod's identity and storage attachment, but the database itself or a separate operations tool must handle functions such as data replication and leader election.

## 5. DaemonSets: Placing the Same Role on Every Node

![ReplicaSet application Pods and DaemonSet Pods on every Node](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/10-daemonset-node-agents.svg)

A **DaemonSet** is a workload resource that manages one Pod on every Node, or on every Node matching specified conditions. Unlike a Deployment, which declares a fixed count through `replicas`, a DaemonSet's Pod count follows the number of target Nodes. When a new Node is added, Kubernetes creates the Pod on that Node. When a Node is removed, Kubernetes cleans up its Pod.

Collecting Node logs or monitoring Node state requires the same agent to run on every Node. Components such as network plugins or storage drivers also need to provide functionality close to each Node. If you run only a fixed number of these programs through a Deployment, some Nodes may have no agent while another Node may have more than one. A DaemonSet matches this requirement.

```yaml
# DaemonSet running one app=log-agent Pod on every target Node
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-agent
spec:
  selector:
    matchLabels:
      app: log-agent
  template:
    metadata:
      labels:
        app: log-agent
    spec:
      containers:
      - name: log-agent
        image: my-log-agent:1.0
```

## 6. Separating Runtime Configuration with ConfigMaps and Secrets

If development and production addresses, log levels, and passwords are all placed inside a container image, every configuration change requires rebuilding the image. Sensitive values may also remain exposed in the image or manifest. Kubernetes provides ConfigMaps and Secrets to separate application code from environment-specific configuration.

### 6.1 ConfigMaps for Ordinary Configuration

A **ConfigMap** stores non-secret configuration as key-value data. The same container image can receive a development address in a development environment and a production address in production. A Pod can consume ConfigMap values as environment variables, command arguments, or configuration files mounted through a volume.

```yaml
# ConfigMap storing ordinary application configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  LOG_LEVEL: info
  DATABASE_HOST: database
```

A ConfigMap does not provide confidentiality. Do not store values such as passwords or tokens that must remain private in a ConfigMap.

### 6.2 Secrets for Sensitive Values

A **Secret** is a resource intended for sensitive data such as passwords, tokens, and certificates. Like a ConfigMap, a Pod can consume Secret values as environment variables or volume files. It is a separate resource kind so that permissions and handling appropriate for sensitive values can be applied.

```yaml
# Secret storing a database username and password
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
type: Opaque
stringData:
  username: web
  password: "change-me"
```

Using a Secret does not automatically make a value completely secure. Values under `data` use Base64 encoding, which represents binary data as text; Base64 encoding is not encryption. In the default configuration, a Secret may be stored unencrypted in **etcd**, the database that stores Kubernetes API resources. In production, minimize permission to read Secrets and also consider encryption at rest and an external secrets-management approach.

### 6.3 Using ConfigMaps and Secrets from a Pod

The following example shows a Deployment Pod template reading ConfigMap and Secret values into environment variables.

```yaml
# Pod template fragment consuming ConfigMap and Secret values as environment variables
spec:
  containers:
  - name: web
    image: my-web:1.0
    env:
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: web-config
          key: LOG_LEVEL
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: database-credentials
          key: password
```

When ConfigMap or Secret values are passed as environment variables, changing the resource does not automatically update an already running process. You generally need to recreate the Pod to apply the new value. Values mounted through a volume can be updated, but you must separately verify whether the application reloads the changed files.

## Before Moving to the Next Article

Here is what we covered in this article. We followed how desired state and control loops from Chapter 2 apply to Pods, workload resources, and runtime-configuration resources.

- A manifest is input that sends desired state to the API, while a resource is an object that Kubernetes stores in the API and manages.
- A Pod is the minimum execution unit in which containers share a Node, networking, and volumes.
- A Deployment manages the number of equivalent Pod replicas and changes to the Pod template.
- A StatefulSet manages Pods for stateful applications that need distinct names and storage.
- A DaemonSet runs a required Pod on every Node or every matching Node.
- ConfigMaps and Secrets separate ordinary and sensitive configuration from container images.

In the next article, we look at Namespaces, which divide resource names and policy scopes; Services, which provide stable addresses for changing Pod sets; and Ingresses, which route external HTTP and HTTPS requests.
