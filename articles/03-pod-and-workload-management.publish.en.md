<!--
  English publication based on 03-pod-and-workload-management.draft.md.
  GitHub Flavored Markdown; figures use GitHub raw URLs.
-->

# Chap03. Pods and Deployments: Application Execution Units and Deployment

> This is the third article in a 16-chapter series. We examine Pods, the smallest units Kubernetes deploys, and the Deployment, StatefulSet, and DaemonSet resources that manage them for different application needs. We also introduce ConfigMaps and Secrets for separating runtime configuration from container images.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/01-k8s-logo.svg)

After starting a web server in one container and seeing its first page, deployment may feel complete. But running three instances as traffic grows introduces new work. A missing instance must be replaced, and a new release requires a plan for replacing the old instances. The command that started the application tells us little about whether it will keep running as intended.

This is where the declarative management introduced in Chapter 2 becomes useful. Instead of finding and managing containers individually, we declare an image and a desired count, and Kubernetes works to maintain that state. We still need to tell it which containers belong to the application and what configuration to use when creating or replacing them.

A **Pod** is the unit in which containers run. A **Deployment** maintains Pods with the same role, such as web servers, and manages changes to their deployment. These concepts turn an instruction to start three containers into a declaration to maintain three instances of an application built from a particular image. This chapter connects those declarations to the resources Kubernetes manages, then explores how management changes with the application's needs.

## 1. Resources and Manifests

Deploying an application involves declaring desired state and submitting it to the API. First, we need to distinguish the manifest we write from the resource the API manages.

![Resources and manifests](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/01-resource-manifest.svg)

A **manifest** declares which resource should exist and what state it should have. Manifests are commonly written in YAML, although JSON is also supported. YAML describes the file format; “manifest” describes its role as a declaration submitted to the Kubernetes API.

A **resource** is something managed through the Kubernetes API, such as a Pod or Deployment. A particular named instance is an **object**. Creating or changing resources in this article means managing those objects through the API. A resource can have a `spec` describing desired state and a `status` recording what Kubernetes observes. As Fig 2 shows, the API Server stores a submitted declaration as a resource in the cluster. Control processes watch that resource and adjust actual state toward the desired state in `spec`. [[1]](#ref-1)

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

### 1.1 Benefits of Manifest-Based State Management

Manifests keep operational configuration from existing only as one-time terminal commands. They record which resources are needed and how each should be configured. Submitting the same manifest in another environment requests the same desired state, reducing manual setup that depends on someone's memory.

Files can be versioned in Git. Teams can review manifest changes like application code and inspect who changed each setting. If a problem occurs, an earlier manifest provides a basis for requesting the desired state it described.

Manifests also serve as automation inputs. A deployment pipeline can submit reviewed files to the API without a person repeatedly assembling commands.

Once desired state is recorded in a file, it must be submitted to the Kubernetes API to take effect. Let's follow how the manifest reaches the cluster.

### 1.2 Manifest Submission with kubectl apply

![Submitting a manifest with kubectl apply](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/02-kubectl-apply.svg)

Suppose the manifest is saved as `app.yaml`. The command `kubectl apply -f ./app.yaml` applies its configuration to the cluster. You can run it from a developer's computer or an automation server with `kubectl` and cluster access configured.

`apply` applies the manifest's configuration to a resource, and `-f` specifies the file to read. Here, `./app.yaml` is a file in the current directory. `kubectl` reads it and submits it to the cluster selected by its connection configuration. [[2]](#ref-2)

```bash
# Submit a local manifest to the selected Kubernetes cluster
kubectl apply -f ./app.yaml
```

kubectl reads `app.yaml`, then obtains the selected cluster's API Server address and credentials from **kubeconfig**. It converts the manifest into API requests and sends them over the network to that server.

The API Server checks identity, permissions, and whether the fields satisfy the API schema. For a valid request, it creates a resource if it does not exist or applies changes to the existing resource. Resource identity includes its type and name.

The result displays `created` for a new resource, `configured` for a changed configuration, or `unchanged` when there is nothing to change. After `kubectl` submits the declaration in Fig 3, control processes reconcile actual state using the resources stored in the API. When the declaration calls for running Pods, they become ready through this subsequent work. Query their status to check whether the application is ready to receive requests.

When creating or updating resources by name, we may need to manage development and production versions of the same application together. In that case, we also need to identify the scope to which each resource belongs.

### 1.3 Namespaces for Resource Names and Management Scope

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/ns.svg" alt="Official Kubernetes Namespace resource icon" width="260">

Imagine managing development and production web servers in one cluster. To use the name `web` in both environments, we need a way to distinguish them. A **Namespace** divides resource names and management scope within a cluster. Creating `dev` and `prod` Namespaces allows each to contain a Deployment named `web`, managed separately. Resources of the same kind must have unique names within one Namespace, but can share a name across different Namespaces. [[3]](#ref-3)

![Pods from dev and prod Namespaces placed across two worker nodes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/15-namespace-and-node-placement.png)

In Fig 4, the outer boundary is one cluster, and the two Nodes inside it are the servers running Pods. Blue Pods belong to `dev`; orange Pods belong to `prod`. The `dev` Pods are spread across Nodes A and B, while each Node runs Pods from both Namespaces. **A Namespace identifies resource membership; a Node identifies the execution location.** Nodes themselves do not belong to a Namespace.

The two Pods on Node A are both named `web-a`, but one belongs to `dev` and the other to `prod`, so they are distinct resources. Selecting `dev` when querying development Pods includes the blue Pods regardless of which Node runs them.

Set a resource’s Namespace with `metadata.namespace` in its manifest. Once the `dev` Namespace exists, the `metadata` section of a development resource looks like this:

```yaml
metadata:
  name: web
  namespace: dev
```

- `metadata.namespace`: the Namespace in which to create or update the resource. This declaration identifies `web` in `dev`.

Queries also select a scope. For example, use the following command to list development Pods:

```bash
kubectl get pods -n dev
```

The `-n dev` option selects the `dev` Namespace. Changing it to `-n prod` lists production Pods. Matching the Namespace used at creation with the scope selected for queries lets us manage each environment separately within the same cluster.

Kubernetes provides a `default` Namespace as a default workspace. When a manifest and command omit the Namespace, `kubectl` uses the Namespace in its current context, falling back to `default` if none is configured. The remaining examples in this chapter use `default`.

With resource membership established, we can examine how containers are grouped for execution. That execution unit is the Pod.

## 2. Pods for Containers That Run Together

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/pod.svg" alt="Official Kubernetes Pod resource icon" width="260">

### 2.1 The Smallest Deployable Unit

![Kubernetes Pod](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/fig05-12-pod-scheduling-and-sharing.svg)

A **Pod** groups one or more containers into the smallest unit Kubernetes creates and schedules onto a node. Containers in the same Pod, such as Container A and B in the diagram, are always placed on the same node. [[4]](#ref-4)

Creating a Pod requires choosing a Node on which to run it. The **Scheduler** in Fig 5 handles this in the Control Plane. It checks the Pod's resource requirements and placement constraints, selects a Worker Node, and records the assignment through the API Server.

Once a Node is selected, its **Kubelet** checks the API Server for the Pod assigned to it. It then requests container execution from the runtime through **CRI**, introduced in Chapter 2. The runtime prepares the images declared in the Pod and starts the containers. The Kubelet continues managing the Pod by checking execution status through the runtime and reporting the results to the API Server. This is how a Pod declaration stored in the API becomes running containers on the assigned Node.

In practice, a Pod with one application container is the most common arrangement. Even then, the Pod gives Kubernetes a consistent unit for placement, networking, storage, and lifecycle management.

Multiple containers belong in a Pod when they need to cooperate closely: they must be placed together, share networking or files, and be removed together when the Pod disappears. A Pod therefore defines which containers form one application execution unit, rather than merely acting as a container wrapper.

![A Pod groups containers](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-pod.png)

The two containers share an environment, but they do not necessarily restart simultaneously. If one exits, the kubelet can restart only that container under its restart policy while keeping the Pod.

Networking is shared at the Pod level. Containers use the same Pod IP and port space. Processes listening on the same address and protocol need different ports, and containers can reach one another through `localhost`. This shared network is why external clients reach processes through the Pod IP rather than a separate address for each container. [[4]](#ref-4)

Storage can also be shared. A **volume** connects storage to a Pod for its containers to use. Declare the volume once and mount it in multiple containers to let them read and write the same files. Their default filesystems remain separate; only the mounted paths share that storage.

Because of these shared boundaries, unrelated applications should not be grouped in one Pod. A web server and a database with different deployment schedules and scaling needs generally belong in separate Pods. Group only containers that need joint placement and deletion and close sharing of networking or files.

### 2.2 The Sidecar Pattern

![A sidecar collecting application logs](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/fig06-06-sidecar-logging.svg)

The **sidecar pattern** takes advantage of these shared boundaries. A supporting container runs alongside the main application container to provide a function such as log collection, proxying, or configuration updates within the same environment. [[5]](#ref-5)

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

When several Pods serve the same role, maintaining the application's Pod population matters more than preserving one Pod's name or IP. Pods can disappear during failures or deployments and be replaced under new names and addresses. The operational goal is the state of the group, rather than the identity of one particular Pod.

A **Deployment** declares and maintains the desired state of this group. Users specify how many Pods of a given configuration should exist and how that configuration should be replaced. Controllers read the declaration and adjust the group's count and configuration. This applies Chapter 2's control loop to application deployment.

![A Deployment manages Pods and rollout state](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-deployment.png)

The illustration shows a checklist holder overseeing several Pods, representing how a Deployment manages a Pod set toward its desired state. Fig 7 shows the components involved in carrying out that management.

![Kubernetes Deployment](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/fig07-12-deployment.svg)

Fig 7 shows three Pods running the same version of a web application. On the left, `replicas: 3` declares the desired Pod count, and `Pod template: image v1` specifies the image for new Pods. The user declares these values, and the controller responsible for the Deployment creates a **ReplicaSet** to manage that group of Pods.

The ReplicaSet in the middle maintains the desired count. Its controller checks how many Pods it manages and requests new Pods from the same template when more are needed. The figure's desired count of three and current count of three indicate that the count is satisfied. The three Pods on the right have different names, but use the same image and share the label `app=web`. The ReplicaSet's `Selector: app=web` identifies the group to manage. The next section connects that label and selection condition to a manifest.

Once Pods are created, the Scheduler below chooses a Node for each one. It evaluates each Pod's resource requirements and placement constraints separately, so the Pods can be assigned to different Nodes. This figure places one Pod on each of Worker Nodes A, B, and C; ensuring such a distribution requires placement constraints in addition to a replica count. The Kubelet and runtime on each assigned Node then start the containers.

The Deployment declares the configuration and number of Pods to deploy, the ReplicaSet maintains their count, and the Scheduler chooses where they run. The arrows summarize how these components continue their work by reading declarations and assignments recorded through the API Server.

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

A **replica** here is one independent Pod created from the same Pod template. `replicas: 3` means maintaining three Pods with the same role. They have separate names and IP addresses and can be replaced independently during failures or deployment changes.

To change the Pod count, update the Deployment's `replicas` and apply it again. Once the new count reaches the ReplicaSet, its controller creates missing Pods or removes excess ones. To change the execution configuration of new Pods, update the Deployment's Pod template. [[6]](#ref-6)

![Labels and selectors identify a managed Pod group](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/fig08-07-deployment-selector.svg)

A cluster runs Pods for different roles, such as web applications, databases, and log collectors. To fulfill “maintain three web Pods,” Kubernetes needs a way to distinguish those Pods from the rest. Individual names differ and can change during replacement, so maintaining a list of names is impractical.

A **Label** classifies resources so that objects belonging to the same application or role can be grouped. For example, web Pods can carry `app: web`, while log collectors carry `app: log-agent`. Here, `app` is the classification key and `web` is its value. Users choose these keys and values to suit the application's roles.

A **selector** reads labels as conditions that define which resources to manage or query. Even when Pods have labels, a Deployment needs a condition identifying its target group. `selector.matchLabels.app: web` selects Pods whose `app` value is `web`. Pods labeled `app: log-agent` do not match and are not counted as web replicas. Labels classify the targets; selectors choose targets using that classification. [[7]](#ref-7)

This explains why `app: web` appears twice. `spec.selector.matchLabels` declares **the selection condition**, while `spec.template.metadata.labels` declares **the information attached to new Pods**. One locates targets; the other ensures new targets satisfy the condition. A Deployment's Pod template labels must satisfy its selector, or the API rejects the manifest.

If a web Pod is deleted and replaced by one with a new name and IP, the replacement still receives `app: web` from the template. As Fig 8 shows, the shared label survives the name change, so the existing Selector still identifies the managed group. The ReplicaSet beneath the Deployment maintains the count of that group. Users therefore do not need to rewrite a list of Pod names after every replacement. Applications managed independently should use distinct label conditions to keep their management scopes from overlapping.

### 3.2 ReplicaSets and Deployment Changes

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/rs.svg" alt="Official Kubernetes ReplicaSet resource icon" width="260">

To release a new version of the web application, change the image in the Deployment's Pod template. Kubernetes must distinguish old Pods from new ones and replace them while keeping Pods available.

![Pod template replacement through ReplicaSets](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/fig09-09-deployment-replicaset-update.svg)

A ReplicaSet represents a particular version of a Pod template. Changing the Deployment image from `my-web:1.0` to `my-web:1.1` creates a ReplicaSet for the new template. In Fig 9, the Deployment gradually reduces the old ReplicaSet's desired count from three to zero and increases the new one's count from zero to three. Their controllers remove or create Pods to match those counts, replacing the old version. This is a **rolling update**. If the previous ReplicaSet's revision remains available, a user can request a **rollback** to its Pod template. [[8]](#ref-8)

## 4. StatefulSets for Stable Pod Identity

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/sts.svg" alt="Official Kubernetes StatefulSet resource icon" width="260">

![Deployments and StatefulSets for web servers and databases](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/fig10-10-deployment-vs-statefulset-scenarios.svg)

Deployment Pods are assumed to serve the same role and be interchangeable. If a web server Pod disappears, another created from the same template can replace it, and clients do not need to distinguish which instance handles a request. Not all applications fit that model.

A **StatefulSet** manages stateful applications whose Pods need distinct identities. Its Pods have ordered names such as `database-0` and `database-1`. A replacement reuses the name associated with that ordinal, allowing the application to distinguish instances.

This is useful for databases and messaging applications that identify instances by name and require an ordered startup. [[9]](#ref-9)

The following excerpt from a StatefulSet manifest declares the Pod naming prefix and replica count.

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

The default creation order is `database-0`, `database-1`, then `database-2`. Each preceding Pod must be running and ready before the next is created. Reducing the replica count from three to two removes the highest ordinal, `database-2`, first. StatefulSets suit applications that require this identity and ordering. [[9]](#ref-9)

## 5. DaemonSets for a Function on Every Node

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/ds.svg" alt="Official Kubernetes DaemonSet resource icon" width="260">

![DaemonSet agents on each node](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/03/en/fig11-11-daemonset-node-agents.svg)

A **DaemonSet** maintains one Pod on every node, or on each node that matches its conditions. Unlike a Deployment's fixed `replicas` count, its Pod count follows the number of eligible nodes. Adding a node creates a Pod there; removing a node also removes its associated Pod. [[10]](#ref-10)

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

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/cm.svg" alt="Official Kubernetes ConfigMap resource icon" width="260">

A **ConfigMap** stores nonconfidential settings as key-value pairs. The same image can receive development addresses in one environment and production addresses in another. Pods can consume these values through environment variables, command arguments, or configuration files in a volume. [[11]](#ref-11)

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

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/secret.svg" alt="Official Kubernetes Secret resource icon" width="260">

A **Secret** stores sensitive data such as passwords, tokens, and certificates. Like ConfigMaps, Secrets can supply environment variables or volume files. They are a separate resource type to support permissions and handling appropriate for sensitive values. [[12]](#ref-12)

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

- `metadata.name: database-credentials`: The Secret name referenced by a Pod.
- `type: Opaque`: A general Secret type for user-defined keys and values.
- `stringData`: Accepts unencoded strings, which the API converts and stores in `data`.
- `username` and `password`: Example credentials passed to the application.

Using a Secret does not automatically make a value fully protected. With `stringData`, the manifest still contains plaintext; files holding real credentials must not be committed to a public repository. The `data` field uses Base64 to represent binary data as text, and Base64 is not encryption. In a default configuration, Secrets may be stored unencrypted in **etcd**, the database holding Kubernetes API resources. Production setups should restrict Secret read access and consider encryption at rest and external secret management. [[12]](#ref-12)

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

The example reads `LOG_LEVEL` from `web-config` and `password` from `database-credentials`. Updating a ConfigMap or Secret does not automatically change environment variables in an already running process, so applying new values generally requires recreating the Pod. Mounted values can be updated, but the application must also reread the changed files. [[11]](#ref-11) [[12]](#ref-12)

## Before the Next Article

We applied Chapter 2's desired-state and control-loop model to execution units, workload resources, and configuration resources:

- A manifest is input that submits desired state; resources are the objects Kubernetes stores and manages through its API.
- Namespaces separate resource names and management scope within a cluster.
- A Pod is the smallest deployable unit. Its containers share a node and networking and can mount common volumes.
- A Deployment manages the count of interchangeable Pod replicas and changes to their template.
- A StatefulSet preserves Pod names and ordinals for stateful applications.
- A DaemonSet runs the required Pod on every eligible node.
- ConfigMaps and Secrets separate general and sensitive configuration from images.

The next chapter follows how declared Pods become running applications. We will check whether an application is ready to receive requests as well as running, and explore how Kubernetes checks its health.

## References

- <a id="ref-1"></a>[1] [Kubernetes objects and manifests](https://kubernetes.io/docs/concepts/overview/working-with-objects/)
- <a id="ref-2"></a>[2] [kubectl apply reference](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_apply/)
- <a id="ref-3"></a>[3] [Namespace documentation](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- <a id="ref-4"></a>[4] [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- <a id="ref-5"></a>[5] [Sidecar containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
- <a id="ref-6"></a>[6] [ReplicaSets](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- <a id="ref-7"></a>[7] [Labels and selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- <a id="ref-8"></a>[8] [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- <a id="ref-9"></a>[9] [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- <a id="ref-10"></a>[10] [DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- <a id="ref-11"></a>[11] [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- <a id="ref-12"></a>[12] [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
