<!--
  English publish copy based on 03-pod-and-workload-management.draft.md.
  Image paths use GitHub raw URLs; diagrams use their English SVG variants.
  Image repository: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap03. Pods and Deployments: Application Execution Units and Deployment

> This is the third article in a 15-week series. We examine Pods, the smallest units Kubernetes deploys, and the Deployment, StatefulSet, and DaemonSet resources that manage them for different application needs. We also introduce ConfigMaps and Secrets for separating runtime configuration from container images.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/01-k8s-logo.svg)

Chapter 2 explored how Kubernetes brings actual state toward a user's declaration. Here, we examine the units in which containers run and the resources that manage the number and configuration of application instances.

We begin by distinguishing manifests from resources, then introduce Pods. We focus on Deployments for replica management and deployment changes, compare situations that call for StatefulSets and DaemonSets, and finish with ConfigMaps and Secrets for separating configuration from images.

## 1. Resources and Manifests

Deploying an application involves declaring desired state and submitting it to the API. First, we need to distinguish the manifest we write from the resource the API manages.

![Resources and manifests](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/01-resource-manifest.svg)

A **manifest** declares which resource should exist and what state it should have. Manifests are commonly written in YAML, although JSON is also supported. YAML describes the file format; “manifest” describes its role as a declaration submitted to the Kubernetes API.

A **resource** is something managed through the API, such as a Pod or Deployment. An individual named instance is an **object**. Creating or changing a resource in this article means managing these objects through the API. A resource may have a `spec` describing desired state and a `status` recording observed state. Control processes observe resources stored in the API, not local manifest files, and perform the work needed to realize their `spec`. [[1]](#ref-1)

One manifest file can contain several resource declarations, or an application's resources can be split across multiple files.

Manifests for resources such as Pods and Deployments use the following structure. Other resources, including ConfigMaps and Secrets, use fields other than `spec`.

```yaml
# Common structure of a Kubernetes manifest
apiVersion: <API group and version>
kind: <resource kind>
metadata:
  name: <resource name>
spec:
  <desired state>
```

- `apiVersion`: the API group and version.
- `kind`: the resource type to create.
- `metadata.name`: the resource's name.
- `spec`: the user's desired state.

Kubernetes normally records `status`, so it is omitted from user-written manifests.

### 1.1 Benefits of Manifest-Based State Management

Manifests keep operational configuration from existing only as one-time terminal commands. They record which resources are needed and how each should be configured. Submitting the same manifest in another environment requests the same desired state, reducing manual setup that depends on someone's memory.

Files can be versioned in Git. Teams can review manifest changes like application code and inspect who changed each setting. If a problem occurs, an earlier manifest provides a basis for requesting the desired state it described.

Manifests also serve as automation inputs. A deployment pipeline can submit reviewed files to the API without a person repeatedly assembling commands.

To affect the cluster, a manifest must be submitted with a command such as `kubectl apply`. Editing a local file alone does not change running resources.

### 1.2 Manifest Submission with kubectl apply

![Submitting a manifest with kubectl apply](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/02-kubectl-apply.svg)

`kubectl apply -f` is normally run in a terminal on a developer's computer or a CI server with kubectl and cluster access configured. It does not require logging in to a worker node. The machine running kubectl needs network access to the API Server.

`apply` requests that manifest configuration be reflected in Kubernetes resources. `-f`, short for `--filename`, selects the manifest input. In the command below, `./app.yaml` is a local file relative to the terminal's current directory. Absolute paths, directories containing manifests, and URLs can also be used. The input is selected by `-f`; the destination cluster is selected by the current kubeconfig context. [[2]](#ref-2)

```bash
# Submit a local manifest to the selected Kubernetes cluster
kubectl apply -f ./app.yaml
```

kubectl reads `app.yaml`, then obtains the selected cluster's API Server address and credentials from **kubeconfig**. It converts the manifest into API requests and sends them over the network to that server.

The API Server checks identity, permissions, and whether the fields satisfy the API schema. For a valid request, it creates a resource if it does not exist or applies changes to the existing resource. Resource identity includes its type and name.

The `created`, `configured`, and `unchanged` results mean that the API resource was created, modified, or needed no change. They do not mean the application is ready to run, so Pod status must be checked separately.

We can now examine the resources these declarations describe, beginning with the Pod and then expanding to workload resources that manage groups of Pods for different purposes.

## 2. Pods for Containers That Run Together

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/pod.svg" alt="Official Kubernetes Pod resource icon" width="260">

### 2.1 The Smallest Deployable Unit

![Pod scheduling, execution, and shared environment](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/12-pod-scheduling-and-sharing.svg)

A **Pod** groups one or more containers into the smallest unit Kubernetes creates and schedules onto a node. Containers in the same Pod, such as Container A and B in the diagram, are always placed on the same node. [[3]](#ref-3)

The **Scheduler** on the left runs in the control plane and selects a suitable worker node for a Pod that has not yet been assigned one. It records the assignment through the API Server. The assigned node's **kubelet** observes that Pod through the API Server and asks the container runtime to execute its containers. The runtime prepares images and actually runs container processes. The kubelet continues managing their state afterward.

In practice, a Pod with one application container is the most common arrangement. Even then, the Pod gives Kubernetes a consistent unit for placement, networking, storage, and lifecycle management.

Multiple containers belong in a Pod when they need to cooperate closely: they must be placed together, share networking or files, and be removed together when the Pod disappears. A Pod therefore defines which containers form one application execution unit, rather than merely acting as a container wrapper.

![A Pod groups containers](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-pod.png)

The two containers share an environment, but they do not necessarily restart simultaneously. If one exits, the kubelet can restart only that container under its restart policy while keeping the Pod.

Networking is shared at the Pod level. Containers use the same Pod IP and port space. Processes listening on the same address and protocol need different ports, and containers can reach one another through `localhost`. This shared network is why external clients reach processes through the Pod IP rather than a separate address for each container. [[3]](#ref-3)

Storage can also be shared. A **volume** connects storage to a Pod for its containers to use. Declare the volume once and mount it in multiple containers to let them read and write the same files. Their default filesystems remain separate; only the mounted paths share that storage.

Because of these shared boundaries, unrelated applications should not be grouped in one Pod. A web server and a database with different deployment schedules and scaling needs generally belong in separate Pods. Group only containers that need joint placement and deletion and close sharing of networking or files.

### 2.2 The Sidecar Pattern

![A sidecar collecting application logs](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/06-sidecar-logging.svg)

The **sidecar pattern** takes advantage of these shared boundaries. A supporting container runs alongside the main application container to provide a function such as log collection, proxying, or configuration updates within the same environment. [[4]](#ref-4)

For example, an application writes logs to a file while a log collector reads that file and sends it to external storage. Both containers share a log volume in the same Pod, without needing a separate network filesystem. The following manifest illustrates this arrangement.

```yaml
# Share a temporary volume between two containers in one Pod
apiVersion: v1
kind: Pod
metadata:
  name: api-app
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

- `spec.containers`: the application and log collector that run together.
- `volumeMounts`: the volumes each container uses.
- `mountPath`: where the volume is mounted inside a container.
- `spec.volumes`: the volumes available to the Pod.
- `emptyDir: {}`: temporary storage that lasts for the lifetime of the Pod.

Both containers mount `app-logs` at `/var/log/app`. This example demonstrates volume sharing; actual collection also requires the application to write log files and the collector to configure its inputs and destinations.

Pods are replaceable execution units. A Pod assigned to one worker node does not move to another node. A replacement is a new Pod with a different unique identifier (UID), and it may have a different name and IP. Deleting a standalone Pod does not cause Kubernetes to recreate it automatically. Long-running applications therefore need a higher-level resource to manage Pod counts and replacement.

Kubernetes provides **Deployments**, **StatefulSets**, and **DaemonSets** for these purposes. A Deployment maintains a desired number of interchangeable Pods, such as web API instances. A StatefulSet provides distinct names and creation order. A DaemonSet provides a local function on each eligible node. All three use Pod templates, but they describe different desired Pod populations. We will examine them in that order.

## 3. Deployments for Replicas and Application Updates

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/deploy.svg" alt="Official Kubernetes Deployment resource icon" width="260">

![Kubernetes Deployment](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/12-deployment.svg)

When several Pods serve the same role, maintaining the application's Pod population matters more than preserving one Pod's name or IP. Pods can disappear during failures or deployments and be replaced under new names and addresses. The operational goal is the state of the group, rather than the identity of one particular Pod.

A **Deployment** declares and maintains the desired state of this group. Users specify how many Pods of a given configuration should exist and how that configuration should be replaced. Controllers read the declaration and adjust the group's count and configuration. This applies Chapter 2's control loop to application deployment.

### 3.1 Deployment Declarations and Pod Replicas

The following Deployment maintains three web application Pods. `replicas` specifies the count, and the **Pod template**, `template`, supplies the image and common settings for new Pods. The two occurrences of `app: web` identify the group managed by this Deployment.

```yaml
# Declare three Pod replicas and their common template
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

- `metadata.name: web`: the Deployment's name.
- `spec.replicas: 3`: the number of Pods to maintain.
- `spec.selector.matchLabels`: the **selector**, which identifies the managed group by its labels; here it selects `app: web`.
- `spec.template`: the common configuration for new Pods.
- `spec.template.metadata.labels`: key-value classification information called **labels**, attached to new Pods. Here every new Pod receives `app: web` to match the selector.
- `spec.template.spec.containers`: the containers to run in each Pod.
- `image: my-web:1.0`: an example application image name.
- `containerPort: 8080`: the port the container uses. Declaring it does not make the application listen or create an external access path.

Replace the example image with your own application image.

A **replica** is one independent Pod created from the same Pod template. `replicas: 3` means maintaining three Pods serving the same role, not running three containers inside one Pod. Each Pod has its own name and IP and can be replaced independently after a failure or configuration change. “Replica” describes the Pod's role; there is no separate resource kind called `Replica Pod`.

A Deployment creates a **ReplicaSet** to maintain the Pod count. The ReplicaSet creates Pods when its managed population is too small and removes extras when it is too large. Users normally express desired changes through the Deployment's `replicas` and Pod template rather than editing the ReplicaSet directly. [[5]](#ref-5)

![Labels and selectors identify a managed Pod group](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/07-deployment-selector.svg)

A cluster runs Pods for different roles, such as web applications, databases, and log collectors. To fulfill “maintain three web Pods,” Kubernetes needs a way to distinguish those Pods from the rest. Individual names differ and can change during replacement, so maintaining a list of names is impractical.

A **label** attaches shared classification information to resources so they can be grouped by application or role. Web Pods might carry `app: web`, while log collectors carry `app: log-agent`. Here, `app` is the key and `web` is its value. These values are chosen by users; Kubernetes does not infer the application's role from a Pod name or container image. Labels alone do not create Pods or maintain a replica count.

A **selector** reads labels as conditions that define which resources to manage or query. Even when Pods have labels, a Deployment needs a condition identifying its target group. `selector.matchLabels.app: web` selects Pods whose `app` value is `web`. Pods labeled `app: log-agent` do not match and are not counted as web replicas. Labels classify the targets; selectors choose targets using that classification. [[6]](#ref-6)

This explains why `app: web` appears twice. `spec.selector.matchLabels` declares **the selection condition**, while `spec.template.metadata.labels` declares **the information attached to new Pods**. One locates targets; the other ensures new targets satisfy the condition. A Deployment's Pod template labels must satisfy its selector, or the API rejects the manifest.

If a deleted web Pod is replaced by one with a new name and IP, the new Pod still receives `app: web` from its template. It satisfies the existing selector without changes to a name list. Applications that must be managed independently should use distinct label conditions so their management scopes do not overlap.

![A Deployment manages Pods and rollout state](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-deployment.png)

Changing the image version in the Deployment requires replacing the illustrated Pods with the new configuration. Next, we will examine how ReplicaSets support that change.

### 3.2 ReplicaSets and Deployment Changes

Suppose a web application's image changes while its Pod count must be maintained. Existing and new-version Pods need to be distinguished, and replacement should preserve availability.

![Pod template replacement through ReplicaSets](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/09-deployment-replicaset-update.svg)

A ReplicaSet represents a Pod template at a particular point in time. When the Deployment image changes from `my-web:1.0` to `my-web:1.1`, it creates a ReplicaSet for the new template rather than modifying existing Pods directly. It reduces the old ReplicaSet's count while increasing the new one's. This gradual replacement is the default **rolling update** strategy. If an earlier ReplicaSet's revision remains available, users can request a **rollback** to that Pod template. [[7]](#ref-7)

## 4. StatefulSets for Stable Pod Identity

![Deployments and StatefulSets for web servers and databases](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/10-deployment-vs-statefulset-scenarios.svg)

Deployment Pods are assumed to serve the same role and be interchangeable. If a web server Pod disappears, another created from the same template can replace it, and clients do not need to distinguish which instance handles a request. Not all applications fit that model.

A **StatefulSet** manages stateful applications whose Pods need distinct identities. Its Pods have ordered names such as `database-0` and `database-1`. A replacement reuses the name associated with that ordinal, allowing the application to distinguish instances.

This is useful for databases and messaging applications that identify instances by name and require an ordered startup. [[8]](#ref-8)

The following is a **partial StatefulSet manifest** focused on Pod naming and replica count. It illustrates the management difference from Deployment rather than providing every setting needed for deployment.

```yaml
# Partial StatefulSet manifest illustrating Pod names and replica count
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
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

- `kind: StatefulSet`: selects a resource that maintains distinct Pod names and ordinals.
- `metadata.name: database`: the prefix of the generated Pod names.
- `replicas: 3`: maintains `database-0`, `database-1`, and `database-2`.
- `selector.matchLabels`: the label condition for managed Pods.
- `template.metadata.labels`: labels attached to new Pods; these must match the selector.
- `template.spec.containers`: the common container configuration for each Pod.
- `image: my-database:1.0`: an example database image name.

Like a Deployment, a StatefulSet declares a Pod template and replica count, but it handles names differently. If `database-1` is deleted, a new Pod is created with that name. Reusing a name does not revive the old Pod: the new one has a different UID, and its IP can change.

The default creation order is `database-0`, `database-1`, then `database-2`. Each preceding Pod must be running and ready before the next is created. Reducing the replica count from three to two removes the highest ordinal, `database-2`, first. StatefulSets suit applications that require this identity and ordering. [[8]](#ref-8)

A StatefulSet does not configure database replication or leader election. The database itself or separate operational tooling handles those responsibilities.

## 5. DaemonSets for a Function on Every Node

![DaemonSet agents on each node](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/11-daemonset-node-agents.svg)

A **DaemonSet** maintains one Pod on every node, or on each node that matches its conditions. Unlike a Deployment's fixed `replicas` count, its Pod count follows the number of eligible nodes. Adding a node creates a Pod there; removing a node also removes its associated Pod. [[9]](#ref-9)

Node log collection and monitoring require the same agent on each node. Network plugins and storage drivers can have similar needs. Running only a fixed number of these agents as a Deployment can leave one node without an agent and another with several, so a DaemonSet is a better fit.

```yaml
# Run one app=log-agent Pod on each eligible node
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

- `metadata.name: log-agent`: the DaemonSet's name.
- `spec.selector.matchLabels`: the label condition for managed Pods.
- `spec.template`: the common Pod configuration for each eligible node.
- `image: my-log-agent:1.0`: an example log collector image name.

This example illustrates per-node placement only. Collecting actual node logs also requires access to the log paths and collector configuration.

## 6. Runtime Configuration with ConfigMaps and Secrets

So far, we have examined how Pods are placed and maintained. We now turn to separating configuration so the same image can run in different environments.

Embedding development and production addresses, log levels, and passwords in an image requires rebuilding it whenever settings change. Sensitive values can also remain exposed in images or manifests. ConfigMaps and Secrets separate application code from environment-specific configuration.

### 6.1 ConfigMaps for General Settings

A **ConfigMap** stores nonconfidential settings as key-value pairs. The same image can receive development addresses in one environment and production addresses in another. Pods can consume these values through environment variables, command arguments, or configuration files in a volume. [[10]](#ref-10)

```yaml
# Store general application settings in a ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  LOG_LEVEL: info
  DATABASE_HOST: database
```

- `metadata.name: web-config`: the name referenced by the Pod.
- `data`: the configuration values supplied to the application.
- `LOG_LEVEL`: an example logging level.
- `DATABASE_HOST`: an example database address.

ConfigMaps provide no confidentiality. Do not use them for passwords or tokens that must remain private.

### 6.2 Secrets for Sensitive Values

A **Secret** stores sensitive data such as passwords, tokens, and certificates. Like ConfigMaps, Secrets can supply environment variables or volume files. They are a separate resource type to support permissions and handling appropriate for sensitive values. [[11]](#ref-11)

```yaml
# Store an example database username and password in a Secret
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
type: Opaque
stringData:
  username: web
  password: "change-me"
```

- `metadata.name: database-credentials`: the name referenced by the Pod.
- `type: Opaque`: the general-purpose Secret type for user-defined key-value data.
- `stringData`: accepts unencoded strings that the API converts and stores in `data`.
- `username` and `password`: example credentials; `change-me` is a placeholder, not a real password.

Using a Secret does not automatically make a value fully protected. With `stringData`, the manifest still contains plaintext; files holding real credentials must not be committed to a public repository. The `data` field uses Base64 to represent binary data as text, and Base64 is not encryption. In a default configuration, Secrets may be stored unencrypted in **etcd**, the database holding Kubernetes API resources. Production setups should restrict Secret read access and consider encryption at rest and external secret management. [[11]](#ref-11)

### 6.3 ConfigMap and Secret References in Pods

The following Deployment Pod-template excerpt reads values from a ConfigMap and a Secret into environment variables.

```yaml
# Deployment Pod-template excerpt using ConfigMap and Secret values
spec:
  template:
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

- `env[].name`: the environment variable passed to the container.
- `valueFrom.configMapKeyRef`: reads a value from a ConfigMap.
- `valueFrom.secretKeyRef`: reads a value from a Secret.
- Each reference's `name`: the ConfigMap or Secret to read.
- Each reference's `key`: the entry to retrieve from that resource.

The example reads `LOG_LEVEL` from `web-config` and `password` from `database-credentials`. Updating a ConfigMap or Secret does not automatically change environment variables in an already running process, so applying new values generally requires recreating the Pod. Mounted values can be updated, but the application must also reread the changed files. [[10]](#ref-10) [[11]](#ref-11)

## Before the Next Article

We applied Chapter 2's desired-state and control-loop model to execution units, workload resources, and configuration resources:

- A manifest is input that submits desired state; resources are the objects Kubernetes stores and manages through its API.
- A Pod is the smallest deployable unit. Its containers share a node and networking and can mount common volumes.
- A Deployment manages the count of interchangeable Pod replicas and changes to their template.
- A StatefulSet preserves Pod names and ordinals for stateful applications.
- A DaemonSet runs the required Pod on every eligible node.
- ConfigMaps and Secrets separate general and sensitive configuration from images.

The next article follows a Deployment declaration through Pod and container execution. We will distinguish Pod and container states, examine probes and graceful termination, and see how Kubernetes responds to failures within a Pod and failures of an entire node.

## References

- <a id="ref-1"></a>[1] [Kubernetes objects and manifests](https://kubernetes.io/docs/concepts/overview/working-with-objects/)
- <a id="ref-2"></a>[2] [kubectl apply reference](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_apply/)
- <a id="ref-3"></a>[3] [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- <a id="ref-4"></a>[4] [Sidecar containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
- <a id="ref-5"></a>[5] [ReplicaSets](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- <a id="ref-6"></a>[6] [Labels and selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- <a id="ref-7"></a>[7] [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- <a id="ref-8"></a>[8] [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- <a id="ref-9"></a>[9] [DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- <a id="ref-10"></a>[10] [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- <a id="ref-11"></a>[11] [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
