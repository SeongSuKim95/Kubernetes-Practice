<!--
  English publication based on 02-understanding-kubernetes.draft.md.
  GitHub Flavored Markdown; figures use GitHub raw URLs.
-->

# Chap02. The Design Philosophy of Kubernetes

> This is the second article in a 16-chapter series. We explore declarative configuration, control loops, and Watch-based communication, then connect these principles to the Kubernetes API and cluster architecture.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/01-k8s-logo.svg)

Chapter 1 explained how containers and Docker make runtime environments consistent. The exercise showed that starting a container still leaves work to do: restarting stopped containers, adding instances, and replacing images. Running containers and maintaining an application's operational state are different responsibilities.

Kubernetes manages this work by bringing the actual state toward the state users declare. Before memorizing component names, it helps to understand how that declaration is shared and how differences from the actual state are reduced.

This article introduces three design principles: declarative configuration, control loops, and subscriptions to state changes through Watch. We then examine how the API and cluster components implement those principles, and how a declaration results in running Pods. Finally, we compare the manual operations in Chapter 1 with Kubernetes commands.

## 1. Kubernetes and Its Ecosystem

Kubernetes is a **container orchestration** platform. Container orchestration automates placement, instance counts, recovery, and traffic distribution rather than merely starting containers. Kubernetes is an open-source platform that coordinates these operations across servers. [[1]](#ref-1)

Since its release in 2014, contributors around the world have developed it. Major cloud providers offer managed Kubernetes, and the same model can also run locally. A consistent operational approach across environments is one reason it has become a de facto standard.

![The Kubernetes ecosystem](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/02-k8s-ecosystem.svg)

Fig 2 shows deployment automation, monitoring, networking, storage, and security tools around Kubernetes. Together, these tools provide the capabilities needed to operate applications beyond simply running them.

Portability also contributes to its popularity. Applications built for Kubernetes can use the same declarative approach when deployed in different environments. Operational tools integrate through these shared declarations and APIs.

This does not make Kubernetes easy to learn. At first, the many names and configuration files can seem unnecessarily complex. With familiarity, attention shifts to what the platform can do. We will follow that progression through **motivation, design principles, core concepts, the path from declaration to execution, and command comparisons**.

## 2. Operational Needs Beyond Docker

As the previous article showed, starting several containers is not especially difficult. The harder part is **operational decisions and policies**. Docker standardizes runtime environments, and Dockerfiles record their construction as code.

```bash
# Recall the basic Docker image build and run workflow
docker build -t my-app:1.0 .
docker run -p 8080:80 my-app:1.0
```

Using the same image locally, in testing, and in production greatly reduces environment mismatches. Compose groups containers into an application, and Swarm distributes them across servers. This raises a reasonable question:

“If Docker Compose or Docker Swarm is sufficient, why use Kubernetes?”

> Docker runs containers; Kubernetes is an **orchestration platform** for managing the system in which containers run.

![Docker tools and Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/21-docker-tools-vs-k8s.svg)

The left side of Fig 3 expands from running containers with Docker to configuring one server with Compose and operating multiple servers with Swarm. On the right, Kubernetes accepts declarations of desired state and operational policies, then performs placement and recovery against those criteria.

Kubernetes is not mandatory when Compose or Swarm meets the operational requirements. The distinction involves not only whether scaling is possible, but who decides when and how far to scale.

In Swarm, administrators often increase the service replica count manually when traffic rises.

```bash
# Manually request scaling in Swarm
docker service scale web=10
```

Scaling is available, but a person decides **when to add or remove instances and how many to maintain**. Kubernetes can use a policy based on a condition such as CPU utilization, delegating subsequent scaling decisions and actions to the platform. For example, a policy can target increased capacity when CPU utilization exceeds 70%.

Recovery also depends on configuration. Docker restart policies can restart exited containers on the same host, while Swarm maintains replicas across servers. Kubernetes divides container restart, replica maintenance, and node failure handling among its components. A single container exit and a whole-server failure follow different recovery paths.

Deployment policies can progressively replace Pods or restore an earlier configuration. More complex strategies, such as sending only part of the traffic to a new version, require routing components or additional deployment tools. It is important to distinguish built-in capabilities from those requiring extra configuration.

Recording operational decisions as policies requires a platform that continuously checks the declared goal.

## 3. Core Design Principles

Looking only at which component automates which task can leave a long list of names. Three principles provide a common thread for the concepts that follow.

### 3.1 Declarative Configuration and Desired State

A typical Docker command looks like this:

```bash
# Imperative execution: start a container now
docker run -d nginx
```

It instructs the system how to start something now. The command itself does not keep managing its state afterward. This is an **imperative** approach.

In Kubernetes, users commonly describe the desired state in **YAML**, a configuration format whose structure is expressed through indentation. A declaration submitted to the API is called a **manifest**. A **resource** is something managed through the Kubernetes API; a manifest is input for creating or changing it. A target of three replicas can be expressed as `replicas: 3`.

```yaml
# Record desired state in a YAML manifest
replicas: 3
```

![Desired and actual state](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/04-desired-state.svg)

The key is **desired state**: a statement of how things should be, rather than a report of what is running now. As with Compose YAML, the user records a goal and gives it to a platform. The difference lies in what the platform is responsible for after receiving it. [[2]](#ref-2)

In Fig 4, the platform compares the desired count of three replicas with the current count, finds one missing, and restores the count to three. Desired state remains the comparison target after the startup command has finished.

Declaring “keep three replicas running” instead of specifying a one-time startup action is a **declarative** approach.

Keeping configuration in files also makes changes easier to review and compare. A replica count change from three to five can be recorded in Git, showing who changed an operational setting. The updated declaration must then be submitted to the cluster; editing a local file alone does not change it.

### 3.2 Control Loops

![The control loop](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/05-control-loop.svg)

A **control loop** repeatedly observes the **current state** and reduces its difference from the desired state. An individual corrective operation is called **reconciliation**.

A control loop does not stop after checking once. It requests a change and observes the result again, allowing it to discover new differences caused by failures or configuration changes. [[3]](#ref-3)

In Fig 5, the API records a desired count of three and a current count of two. The process managing replicas detects the difference, requests creation of the missing instance through the API, and observes the result again. Once a server is selected and the new replica starts there, the count returns to three. Automatically restoring state after a failure in this way is called **self-healing**.

### 3.3 Event-Based Communication

Maintaining instance counts, selecting servers, and managing container execution are separate jobs. Their coordination is based on changes to shared state. A **Watch** subscribes a component to those changes.

Comparing **direct calls** with **shared state plus Watch** explains why this matters.

![Direct calls and Watch-based coordination](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/15-direct-vs-watch.svg)

With direct calls, one process hands work to the next by calling it. If the receiving process is down, the handoff must wait at that step.

With shared state and Watch, work is recorded as state, and each process observes the changes relevant to its role. If the placement process stops, new placements must wait, but the recorded requests remain and can be processed after recovery. Other processes can continue managing work that is already running.

Communication does not disappear. Instead, each stage records its result in shared state for other components to observe. Kubernetes shares this information through the **API Server**, the interface for querying and changing state.

Next, we will examine that interface and the components responsible for each task.

## 4. Core Kubernetes Concepts

Building on Docker, Compose, and Swarm, Kubernetes can be understood as a platform for **automating container operations across servers**.

![The Kubernetes API and cluster](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/03-k8s-cluster.svg)

In Fig 7, the user’s declaration passes through the API Server to a cluster containing several Nodes. This separates the API, the interface receiving requests, from the cluster, the environment in which workloads run.

First is the **API**, the entry point for submitting desired state to a cluster. Requests such as “maintain three web containers” or “run this application image” go through the API. A common interface lets users request cluster operations without logging in to each server.

**kubectl** is the principal **command-line client** for this API. Querying or applying configuration in a terminal becomes an API request.

Second is the **cluster**, the logical group of computers in which requests are carried out. Each participating server is a **node**. Like a Swarm cluster, Kubernetes treats multiple nodes as a group, with operational policies and automation layered on top. Users generally request a state for the cluster rather than specifying a particular server, even as nodes are added or removed. Managed cloud services can provide a cluster without requiring users to build it themselves.

The execution unit also differs. Docker commonly operates on a single container. Kubernetes uses a **Pod**, a group of one or more containers placed and managed together, as its smallest deployable unit. Containers in the same Pod share its network and lifecycle. For now, remember that the cluster schedules and deletes Pods as units. [[4]](#ref-4)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-pod.png" alt="A Pod groups containers" width="40%" />

The two containers in the illustration belong to one Pod and are not placed on different nodes.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-node.png" alt="A node runs multiple Pods" width="40%" />

When multiple Pods run on a node, the container processes inside them use that server's CPU and memory.

After a manifest is submitted, the platform determines where the application should run. Components use control loops to reduce the difference between desired and actual state. Whether an application is written in Node.js or Go, Kubernetes works with its image and manifest. A common API and declaration model across languages becomes especially useful as teams grow.

We can now examine which processes run on which servers. We will begin with the **worker node**, where Pods execute, and then cover the **control plane**, which coordinates the cluster.

A cluster is broadly divided into worker nodes and control plane components.

![Kubernetes components](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/06-k8s-components.svg)

The control plane at the top of Fig 8 stores declarations and determines the required work. The worker nodes below run the containers in Pods. Their kubelet and kube-proxy processes also obtain information through the API Server. We will start with the components responsible for execution.

### 4.1 Worker Nodes

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/infrastructure_components/labeled/node.svg" alt="Official Kubernetes Node resource icon" width="260">

The following processes manage container execution and networking on a worker node.

Each Node’s **Kubelet** is an agent that checks the API Server for Pods assigned to its Node and manages their execution. When a container needs to start, it asks the **container runtime** on the same Node to run it. The runtime downloads images and actually starts or terminates container processes. Examples include containerd and CRI-O.

**CRI** (Container Runtime Interface) defines the communication protocol that lets the Kubelet request execution in a consistent way across different runtimes. Through CRI, the Kubelet requests container startup and shutdown and checks execution status, then reports Pod and Node status to the API Server. [[5]](#ref-5)

When a Node uses Docker Engine, introduced in Chapter 1, **cri-dockerd** provides this connection. It is an adapter that passes the Kubelet’s CRI requests to Docker Engine in a form it can handle. With containerd, execution requests go from the Kubelet to containerd’s CRI implementation. With Docker Engine, they pass through cri-dockerd before reaching Docker Engine. [[6]](#ref-6)

**kube-proxy** implements a stable network entry point in front of changing Pods through network rules. It receives the addresses associated with that entry point and configures forwarding from the stable address to actual Pod IPs.

### 4.2 The Control Plane

The **control plane** maintains desired state and makes decisions such as where Pods should run. Its main components are the API Server, Scheduler, Controller Manager, and etcd. [[7]](#ref-7)

The **API Server** is the central Kubernetes API. kubectl and other components, including kubelets and kube-proxy, use it to query or change cluster state. It checks identity, permissions, and request validity before reflecting changes in the state store.

**etcd** is the database holding resource declarations and state. The API Server reads and writes this store. Other components access the information through the API Server rather than accessing etcd directly.

The **Scheduler** identifies Pods that have not been assigned to a node, considers available resources and placement constraints, and selects a node. The worker node's kubelet and runtime handle container execution.

The **Controller Manager** runs multiple **controllers**, processes that execute control loops to maintain desired state. Different controllers handle concerns such as Pod counts and node status. They Watch API resources and request corrective changes when desired and current state differ. They record changes through the API rather than logging in to nodes directly.

In this arrangement, the Scheduler chooses placement, controllers request resource changes, and each kubelet manages execution on its own node.

## 5. The Path from Declaration to Pod Execution

We have introduced the API, cluster, control plane, and worker nodes. Now we will see how they cooperate in a single request flow to turn a declaration into running Pods and containers.

### 5.1 kubectl and kubeconfig

![kubectl and kubeconfig](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/09-kubectl-kubeconfig.svg)

In Fig 9, `kubectl` runs from the user’s terminal, reads the API Server address and credentials from **kubeconfig**, and sends an HTTPS request to that server. The following configuration connects the destination cluster with the user credentials to use.

```yaml
# Select the cluster and user credentials for kubectl
apiVersion: v1
kind: Config
clusters:
- name: my-cluster
  cluster:
    server: https://api.my-cluster.com:6443
users:
- name: my-user
  user:
    token: <token>
contexts:
- name: my-context
  context:
    cluster: my-cluster
    user: my-user
current-context: my-context
```

- `clusters`: API Server addresses for the available clusters.
- `users`: credentials used for authentication.
- `contexts`: connection settings that pair a cluster with a user.
- `current-context`: the name of the currently selected connection setting.

kubectl reads this configuration and sends HTTPS requests to the selected API Server. [[8]](#ref-8)

To understand how a declaration becomes a running Pod, we first need the state storage and sharing model. Kubernetes stores state, and each component subscribes to relevant changes.

### 5.2 State Storage and Watch

![State storage and Watch](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/10-state-and-watch.svg)

The diagram shows the API Server storing requests and components receiving change information through Watch. We will follow a declaration that maintains a replica count and see which component observes which information. [[9]](#ref-9)

![Pod creation sequence](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/09-pod-creation-sequence.svg)

The path from a desired-state declaration to execution on a node has four stages. The numbers match the diagram.

1. **The user submits a declaration.** kubectl sends desired state to the API Server, which validates it and records it in **etcd**. Other components work from this stored declaration.
2. **Controllers adjust the Pod count.** Controllers in the Controller Manager Watch state changes through the API Server. When the desired and actual counts differ, they request the necessary changes, such as creating missing Pods. Those changes are also stored in etcd.
3. **The Scheduler selects a node.** It Watches for unassigned Pods, evaluates resource availability and other conditions, and records an assignment through the API Server. The assignment is stored in etcd too.
4. **The kubelet starts the containers.** The assigned node's kubelet Watches its Pods through the API Server and asks the runtime to execute their containers. Execution status returns through the API Server to etcd. The containers begin running at this stage.

Saving a declaration in the API and starting its containers happen at different times. Users must check execution and readiness separately.

This sequence covers Pod creation and startup. kube-proxy configures networking for request forwarding, so it is not included in the creation sequence.

## 6. Kubernetes High Availability

![Kubernetes high availability](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/14-ha.svg)

If the API and state store exist in only one place, a failure there can disrupt cluster management. **High availability** (HA) distributes these responsibilities so that a component failure does not stop the whole system. This section introduces that structure.

In Fig 12, users send requests to **one address**, backed by three API Servers. If some fail, the remaining servers continue accepting requests. The etcd state store also usually has multiple members, often an odd number such as three. It can continue serving reads and writes while a **quorum**, or majority, remains available. Multiple worker nodes run the Pods below this control plane. This distributes control plane responsibilities across several machines rather than depending on one. [[10]](#ref-10)

## 7. Docker Operations and Kubernetes Commands

The previous article demonstrated manual recovery and changes to container count and configuration, and introduced the need for connectivity between containers. This section is not a cluster installation or execution exercise. The tables illustrate how these operational and request-routing needs translate into Kubernetes commands and declarations.

The tables introduce **Deployment** and **Service**. For now, think of them as a declaration that maintains the desired Pod count and a stable entry point in front of changing Pods, respectively. [[11]](#ref-11) [[12]](#ref-12)

### 7.1 Recovery After a Stop

![Recovery comparison](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/16-scenario-recovery.svg)

On the left of Fig 13, a person restarts a stopped container with `docker start`. On the right, deleting one of two managed Pods causes the platform to create a replacement to restore the desired count. Manually restarting a container becomes a matter of maintaining a declared set of Pods.

| Docker alone | Kubernetes |
| --- | --- |
| `docker stop web-server-1` `docker start web-server-1` | `kubectl delete pod <pod-name>` `kubectl get pods -l app=web` |
| **Limitation:** without a restart policy, someone must restart the container before it serves requests again. | **Improvement:** while the desired replica count remains declared, the platform restores the Pod count. |

### 7.2 Scaling the Instance Count

![Scaling comparison](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/17-scenario-scale.svg)

On the left of Fig 14, adding containers means choosing names and ports and repeating startup commands. On the right, changing a Deployment’s desired count from two to five causes the platform to create the missing Pods. The later Service example explains how requests reach the additional Pods.

| Docker alone | Kubernetes |
| --- | --- |
| `docker run -d --name web-server-5 -p 8084:80 nginx:latest` `docker run -d --name web-server-6 -p 8085:80 nginx:latest` … repeated for each container and port | `kubectl scale deployment web --replicas=5` `kubectl get pods -l app=web` |
| **Limitation:** avoid port conflicts and update the frontend's target list manually. | **Improvement:** declare the Pod count without maintaining a list of host ports. |

### 7.3 Container Image Updates

![Image update comparison](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/18-scenario-update.svg)

On the left of Fig 15, each container requires a stop, removal, and startup to change its version. On the right, setting a new image in the Deployment progressively replaces Pods, with old and new versions temporarily running together. The table uses `rollout status` to inspect progress and `rollout undo` to return to an earlier configuration.

| Docker alone | Kubernetes |
| --- | --- |
| `docker stop web-server-1` `docker rm web-server-1` `docker run -d --name web-server-1 -p 8080:80 nginx:1.25` … repeated per container | `kubectl set image deployment/web nginx=nginx:1.25` `kubectl rollout status deployment/web` `kubectl rollout undo deployment/web` |
| **Limitation:** updates and rollbacks are handled per container, with interruptions during replacement. | **Improvement:** changing the Deployment image progressively replaces Pods; undo restores an earlier Pod template. |

`kubectl set image` changes the Deployment stored in the API, not the local manifest. If files are the source of your deployment configuration, update those files too. A rollback restores a Pod template; it does not roll back database contents.

### 7.4 Request Distribution and Service Discovery

![Request distribution and service discovery](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/19-scenario-service.svg)

On the left of Fig 16, a front-end server lists individual container addresses, so that list must change when containers change. On the right, clients continue using the Service name `web`, while the platform updates the target Pod information behind it. This separates a stable entry point from changing execution targets.

| Docker alone | Kubernetes |
| --- | --- |
| List `host:8080` … `host:8083` in the frontend configuration and restart it; use `docker inspect` to copy IPs into application settings. | `kubectl expose deployment web --port=80 --type=ClusterIP` `kubectl get svc web` |
| **Limitation:** configuration changes with container counts, and changed IPs break connections. | **Improvement:** the Service name remains stable while the platform updates its available Pod targets. |

### 7.5 Removal of Workloads and Entry Points

![Removing workloads and entry points](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/20-scenario-cleanup.svg)

On the left of Fig 17, operators find and remove containers by name. On the right, deleting the Deployment removes its managed Pods, and separately deleting the Service removes the request entry point. The running Pod set and the way to reach it are removed through their respective declarations.

| Docker alone | Kubernetes |
| --- | --- |
| Repeat `docker stop …` / `docker rm …` for each name; inspect volumes and networks separately. | `kubectl delete deployment web` `kubectl delete svc web` |
| **Limitation:** track remaining containers and ports individually. | **Improvement:** remove the desired configuration at the Deployment and Service level. |

Manual recovery, scaling, updates, and address management become a model of **declaring desired state and letting the platform maintain it**.

## Before the Next Article

We connected operational needs beyond Docker to Kubernetes orchestration, then examined declarative configuration, control loops, and Watch-based communication. The API, cluster, control plane, and worker nodes cooperate to turn declarations into running Pods. We also compared how familiar operational tasks are expressed as Kubernetes commands.
The next article examines Pods as container execution units and Deployments as resources for managing Pod counts and deployment state.

## References

- <a id="ref-1"></a>[1] [Kubernetes overview](https://kubernetes.io/docs/concepts/overview/)
- <a id="ref-2"></a>[2] [Kubernetes objects and desired state](https://kubernetes.io/docs/concepts/overview/working-with-objects/)
- <a id="ref-3"></a>[3] [Controllers and control loops](https://kubernetes.io/docs/concepts/architecture/controller/)
- <a id="ref-4"></a>[4] [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- <a id="ref-5"></a>[5] [CRI documentation](https://kubernetes.io/docs/concepts/containers/cri/)
- <a id="ref-6"></a>[6] [Container runtimes and cri-dockerd documentation](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- <a id="ref-7"></a>[7] [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/)
- <a id="ref-8"></a>[8] [Organizing cluster access with kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- <a id="ref-9"></a>[9] [Kubernetes API: Efficient detection of changes](https://kubernetes.io/docs/reference/using-api/api-concepts/#efficient-detection-of-changes)
- <a id="ref-10"></a>[10] [High-availability topology](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/)
- <a id="ref-11"></a>[11] [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- <a id="ref-12"></a>[12] [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
