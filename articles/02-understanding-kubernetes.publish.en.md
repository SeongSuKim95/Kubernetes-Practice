<!--
  English publish copy. Image paths use GitHub raw URLs.
  Korean publish original: 02-understanding-kubernetes.publish.md
  Image repository: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap02. Kubernetes Design Philosophy

> This is the second article in a 15-week series. It focuses on Kubernetes design philosophy—declarative configuration, control loops, and Watch-based communication—and sketches how that philosophy carries into the API and the cluster.

## Introduction

In the previous article, we followed the path from physical servers to VMs, containers and Docker, then Compose and Swarm, and used scenarios to show the manual, repetitive work that remains when you operate with Docker alone. This article builds on those limits. We look first at Kubernetes design philosophy, then sketch how that philosophy connects through the API, the cluster, and the real execution path.

## 1. Where Kubernetes Sits, and Why It Is Popular


<div align="center">

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/01-k8s-logo.svg)

</div>


Kubernetes is a **container orchestration** (Container Orchestration) platform. Container orchestration means a **system that automates** more than running containers: placement, keeping the right replica count, failure recovery, and traffic distribution. It automatically coordinates placement, recovery, and connectivity for containers across many servers. Kubernetes is the open-source platform that emerged to solve that problem.

Since its release in 2014, contributors worldwide have built up the codebase. Major clouds offer managed Kubernetes, and you can run the same model locally. Sharing a similar operating model wherever you run it is one reason it is treated as a de facto standard.


<div align="center">

![Kubernetes surrounding ecosystem](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/02-k8s-ecosystem.svg)

</div>


Portability also backs its popularity. An application built around Kubernetes can try the same declarative deployment style when the environment changes. At the same time, tools for deploy, monitoring, and networking gather around Kubernetes, so you do not have to build every operational capability yourself. Packaging tools, delivery pipelines, and monitoring tools make up that ecosystem.

That does not mean it is easy to learn. At first, the many names and config files often prompt “Why is this so complex?” Once you settle in a bit, the question often shifts toward “It can do that too?” This article follows that order: rather than memorizing every name up front, we walk through **need, design philosophy, core concepts, how a declaration becomes real execution, and a look through commands**.

## 2. What Docker Alone Does Not Cover

As the previous article already showed, running several containers is not hard by itself. The hard part is **operational judgment and policy**. After Docker arrived, containers became central to standardizing the runtime environment, and Dockerfiles let you keep that environment as code.

```bash
# Reminder of the basic Docker image-build and run flow
docker build -t my-app:1.0 .
docker run -p 8080:80 my-app:1.0
```

Being able to align local, test, and production with the same image greatly reduced environment drift. Docker Compose can group several containers as one application, and Docker Swarm can spread them across servers. So a natural question follows:

“Aren’t Docker Compose or Docker Swarm enough? Why do we need Kubernetes?”

> Docker is a “tool for running containers.” Kubernetes is an **orchestration platform** that manages the whole system where containers run.


<div align="center">

![Docker family and Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/21-docker-tools-vs-k8s.svg)

</div>


On a single server, Docker Compose is often enough. Across several servers, Docker Swarm can also support a useful level of operations. Swarm can deploy services, scale them, and do rolling updates. As scale and requirements grow, though, it falls short of **automating operations and encoding policy in the system** beyond run and replicate.

Docker Swarm was a good way for Docker-familiar teams to start multi-server deploy quickly. As services grow, though, **tools that leave operational policy in the system** are relatively thin—things like resource limits, autoscaling, communication scope, storage, and permissions. Kubernetes offers richer policy for those concerns, and the industry uses it as the de facto orchestration standard.

When traffic spikes, Swarm often needs an admin to set the service replica count by hand.

```bash
# Example showing that Swarm scaling is a human-issued command
docker service scale web=10
```

Scaling is possible, but **when to grow or shrink container count, and by how much**, stays with people. Kubernetes flips the problem: you leave a condition such as CPU usage as policy, and leave later scale decisions and execution to the platform. For example, you can define a goal like “If CPU usage exceeds 70%, increase container replicas automatically.”

Failure is similar. If a container dies at 3 a.m. and you only have Docker, a person runs `docker ps`, checks logs, and runs `docker restart`. With Kubernetes, the platform keeps trying to close the gap between **the Desired container count and the containers that are actually running**. That can mean choosing which server should host a container, then starting the container again on that server. Recovery can start without human intervention—that is a major difference between Docker and Kubernetes.

Deploy differs too. Swarm provides basic rolling updates. Kubernetes often also covers sending **only part of the traffic to a new version** instead of all of it—running old and new side by side and switching over (blue-green), or exposing the new version first to a small set of users (canary). That is less a feature-list gap and more a gap in **how far you can control operational risk**.

In short: Docker is strong at building and running container images. Docker Compose files multi-container layout on one server. Docker Swarm helps spread containers across servers. Kubernetes is the orchestration platform that packages, in a near-standard way, the **operational automation and policy** you need as scale grows.

## 3. Core Design Philosophy of Kubernetes

If you see orchestration only as “who automates what,” the names pile up. If you first pin three promises Kubernetes tries to keep, the core concepts that follow read as one flow. Below, each idea starts with one sentence, then the explanation.

### 3.1 Declarative Style and Desired State

With Docker you often run like this:

```bash
# Imperative run: a Docker example that says “start now”
docker run -d nginx
```

This style is closer to **commanding** “how to run it,” and the system does not keep owning state after execution. That style is called **imperative** (Imperative).

Kubernetes takes another approach. Day to day, you write goals in **YAML** (a config file format that expresses structure with indentation). What you write is called a **manifest** (manifest, a specification of application and ops settings) or a **resource** (resource, an object you submit to the ops system). A goal such as “keep three container replicas” can be left as one line in a manifest, like `replicas: 3`.

```yaml
# Example of leaving Desired State in a YAML manifest
replicas: 3
```


<div align="center">

![Desired State and Current State](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/04-desired-state.svg)

</div>


The heart of this declaration is **Desired State**. It is not “what is running how many right now,” but a goal that says **“I want it to be like this.”** As with Docker Compose YAML, you write the goal and hand it to the platform. The difference is who owns responsibility after the config is submitted.

With Docker alone, when a container dies a person presses `docker start` to match the wanted state. With Kubernetes, the platform compares **Desired State** and **Current State**. If they diverge, it starts or stops containers, or moves them to another server, to shrink the gap. Leaving a goal of **“three must keep running from now on”** rather than a one-shot “start three right now” is the **declarative** (Declarative) style. This automatic alignment is also called **self-healing** (self-healing).

Declarative strength is not only auto-recovery. Ops settings live as YAML manifests, so you can treat infrastructure and deploy like code. You can leave changes as Git commits, and recreate the same state from the files alone. You can review ops changes and re-apply a previous commit’s manifests. Teams often extend this into **IaC** (Infrastructure as Code) and further into **GitOps** (an ops style that aligns cluster state to manifests in a Git repo).

### 3.2 Control Loop


<div align="center">

![Control Loop](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/05-control-loop.svg)

</div>


Define a **Control Loop** in one sentence: it is a **repeating mechanism in which the platform keeps observing current state and, when that differs from the Desired State the user declared, automatically moves toward Desired State**. One alignment action that shrinks the gap is called **reconcile** (Reconcile).

Two points matter. First, Kubernetes is not a “run a command and done” system; it is a system that **maintains state**. Second, the Control Loop is less one button and more how Kubernetes works overall. It reads Desired and Current State, computes the gap, **requests** a reconcile to shrink that gap, then observes state again. Not finishing in one shot is the point.

For example, if the goal is “three container replicas” and one replica drops at 3 a.m., Desired is 3, Current is 2, and the gap is 1. The flow creates a new replica, chooses a server for it, and runs it to get back to 3. So self-healing is less a special feature and more a **natural result of a Control Loop that tries to keep Desired State**. In one line: the center requests state alignment, and each server owns actual execution—a separation of responsibility.

### 3.3 Event-Driven Communication

What moves here is not the **worker server** that hosts containers, but **processes** running inside the platform. Those processes **do not call each other with direct commands.** Instead they **subscribe** (Watch) to changes in a central **shared state**, and each does only its own job. For example, a **match-container-count process**, a **choose-target-server process**, and a **run-containers process** each do only their work.

Why this shape is clearer when you compare **direct calls** with **shared state + Watch**.


<div align="center">

![Direct calls vs Watch](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/15-direct-vs-watch.svg)

</div>


With **direct calls**, the match-container-count process calls the choose-target-server process directly. That process then calls the run-containers process. Calls form one chain. If the choose-target-server process stops, the run-containers process never gets the next command. Failure propagates along the **call path** to the next process.

With **shared state + Watch**, processes do not call each other. Desired State such as “keep three containers” lives only in the shared state store. Each process Watches those state changes, does only its own job, then writes container state back to shared state. Even if the choose-target-server process pauses briefly, shared state remains, and the match-container-count and run-containers processes can continue work in their subscription scope.

Apply the same idea to a 3 a.m. failure. The drop of one container replica is recorded in shared state. The match-container-count process sees the gap and reconciles. The choose-target-server and run-containers processes move when they see state changes they care about. One process does not need to wake another.

With **loose coupling**, one process failure is less likely to stop the whole flow at once. In Kubernetes, **“what was recorded in shared state”** matters more than “who called whom.”

With design philosophy in place, we move to where that philosophy actually applies: **core Kubernetes concepts**.

## 4. Core Kubernetes Concepts

Earlier we summarized the roles of Docker, Docker Compose, and Docker Swarm. On that line, think of Kubernetes as a **platform that automates operations for containers spread across many servers**.


<div align="center">

![Kubernetes API and cluster](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/03-k8s-cluster.svg)

</div>


In practice you meet two cores most often.

First is the **API**. The API is the **entry point** where users deliver Desired State to the cluster. Requests such as “keep three web containers” or “run this application with this image” go through the API. One entry point matters: you do not need to log into each server separately; the same API takes cluster ops requests.

The tool you use most often to talk to that API is **kubectl**. kubectl is a **command-line client** that calls the Kubernetes API. Lookup and apply commands in the terminal become API requests underneath.

Second is the **Cluster**. A cluster binds many machines into **one logical unit**—the scope where those requests actually run. Each server in the cluster is a **Node** (Node, a server that participates in the cluster). Just as Docker Swarm binds many servers into one cluster, a Kubernetes cluster treats many nodes as one whole. On top of that, it places more ops policy and automation rules. As nodes grow or shrink, users usually entrust “keep this state” to the whole cluster rather than naming a specific server. In the cloud, teams often consume such clusters as managed services instead of building them themselves.

Here we name one more idea. With Docker, the usual unit of execution was **one container**. Kubernetes widens that unit one step: a **Pod** is the smallest execution unit—one or more containers **placed and managed together**. Containers in the same Pod share network and lifecycle. For now, it is enough to know that the cluster starts and stops work in Pod units.

Following the Container character from the previous article, a **Pod** character also appears throughout this series.

<div align="center">

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-pod.png" alt="Learning Kubernetes with Seongsu: Pod character" width="40%" />

*Learning Kubernetes with Seongsu: Pod character*

</div>

The Pod character holds **Containers** in a front pouch, like a kangaroo. The hexagon and cube marks on the pouch recall Kubernetes’ smallest execution unit, and two containers in the pouch suggest that one Pod can hold more than one container.

The servers those Pods actually land on are **Nodes**. A **Node** character also appears throughout this series.

<div align="center">

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-node.png" alt="Learning Kubernetes with Seongsu: Node character" width="40%" />

*Learning Kubernetes with Seongsu: Node character*

</div>

The Node character has a body like a server rack and holds **Pods** in its arms. The cube and gear marks on the necklace signal the machine that actually hosts Pods, and the Pods in its arms show that many Pods live on one node.

When you submit a manifest to the API, the platform reads it and decides which node should run the app. The Control Loop we saw earlier tries to shrink the gap with Current State. Whether the application is Node.js or Go, what matters to Kubernetes is the container image and the manifest. Being able to request ops through the same API and manifest style across languages especially helps as teams grow.

Next we look behind the API and cluster at **which processes do what on which servers**. We start with **Worker Nodes**, where Pods actually run, then the **Control Plane**, which owns decisions.

A cluster splits broadly into **Worker Nodes** (Worker Node, servers where Pods actually run) and the **Control Plane** (Control Plane, components that control the cluster).


<div align="center">

![Kubernetes components](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/06-k8s-components.svg)

</div>


### 4.1 Worker Node

A Worker Node is the machine where Pods actually run. On each node, the processes below work together.

**Kubelet** is the **agent** on each node (a process that talks to the API on the node’s behalf and looks after Pod execution). It fetches “Pods that should run on this node” from the API, calls the Container Runtime below to create, start, or stop containers, and reports Pod and node status back toward the API.

**Container Runtime** is the software that pulls images and **actually starts and stops** container processes. containerd and CRI-O fall here. Kubelet talks to the runtime through **CRI** (Container Runtime Interface, the standard contract for talking to a runtime).

**kube-proxy** turns a **stable entry point** (a fixed name and address in front of a changing Pod set) into real network rules. It takes Pod address info for that entry point and configures delivery so requests to the fixed address reach real Pod IPs.

### 4.2 Control Plane

The Control Plane is the set of components that **control** the cluster. It interprets and maintains Desired State, and makes decisions such as which node should host a Pod. API Server, Scheduler, Controller Manager, and etcd typically run here.

**API Server** is Kubernetes’ **central API**. Calls from `kubectl` above, and requests from other components including Worker Kubelet and kube-proxy, all must pass through here to read or change cluster state. It authenticates and authorizes who made the request and what they may do, validates format, then applies changes to the state store below.

**etcd** is that state store—a **distributed key-value database** that holds cluster state. Resource definitions and Current State are ultimately recorded here, and from the cluster’s view it is treated as the **Single Source of Truth**. etcd is the state store; API Server is the entry point that reads and writes that store.

**Scheduler** notices Pods that still have no node, and decides **only which node should host them**, given each Worker node’s resource headroom and placement constraints. It does not run containers itself. When it records “assign this Pod to this node” through the API Server, that node’s Kubelet later starts the real containers.

**Controller Manager** runs many **controllers** (controller, a unit that runs a Control Loop to keep Desired State) in one process. There is a controller per concern—Pod replica count, node status, and so on. They Watch API Server resources and, when Desired and Current differ, **request** a reconcile to shrink the gap. They do not log into nodes directly; they leave state changes on the API.

This structure matches the design philosophy above (**event-driven communication**). Components do not exchange direct commands; they share work **through state left on the API Server**. Scheduler, Controller Manager, and Kubelet each watch API state changes and do only their own jobs rather than calling each other. So in Kubernetes, **“where and how state was recorded”** matters more than “who commanded whom.”

## 5. From Declaration to a Running Pod

We have named API, cluster, Control Plane, and Worker Node. Now we see how those pieces mesh on **one request path**. We follow the sequence from when a user leaves Desired State to when that declaration becomes a running Pod and containers.

### 5.1 Connecting to the API with kubectl


<div align="center">

![kubectl and kubeconfig](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/09-kubectl-kubeconfig.svg)

</div>


```yaml
# Example kubeconfig that sets which cluster and user kubectl connects as
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

In practice, the tool that most often sends requests to the Kubernetes API is **kubectl**. kubectl is a **command-line client** that calls the Kubernetes API. A terminal command becomes an HTTPS request to the API Server underneath. Which cluster address and which user to connect as is set by the **kubeconfig** file above.

Before we walk the declaration-to-Pod sequence, we pin the shared structure under it. Kubernetes prefers storing state and letting each component subscribe to changes over scattering direct commands to components.

### 5.2 State Storage and Watch


<div align="center">

![State storage and Watch](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/10-state-and-watch.svg)

</div>


> “When a user issues a `kubectl` command, Kubernetes immediately ‘commands’ something elsewhere and runs a Pod.”

In reality it is not **direct control**, but **state storage and state subscription** (Watch). When a user submits a manifest, the API Server stores state in etcd. Controller Manager, Scheduler, and Kubelet Watch API Server state changes, each do only their job (match Pod count, assign a node, run containers), and leave results back on the API Server.

The same structure powers **self-healing**. If a container process disappears on a node and Desired and Current diverge, the Control Loop tries to align state again. The work people repeated with `docker start` in the previous article becomes default platform behavior here.

How that store-and-Watch structure actually chains together looks like the following when you follow the declaration-to-Pod sequence.


<div align="center">

![Component sequence](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/09-pod-creation-sequence.svg)

</div>


Below is the path from “Desired State is recorded” to “a Pod runs on a node,” split into four steps. Figure numbers and body numbers match.

1. **The user records a declaration.** kubectl sends Desired State to the API Server. After validation, the API Server records it in **etcd**. This moment is the start of the **declarative** style. Not “start it right here now,” but “it should be in this state” lands in shared state.
2. **Controller Manager matches Pod count.** Controller Manager Watches API Server state changes. When Desired Pod count and actual Pod count differ, it tries to shrink the gap. It leaves another request on the API Server to create missing Pods, and the result is reflected in etcd. This is where the **Control Loop** runs.
3. **Scheduler picks a placement node.** Scheduler Watches Pods that still have no node on the API Server, then records “this Pod belongs on this node” on the API Server after checking resource headroom and similar factors. That assignment is also stored in etcd. Scheduler does not run containers itself.
4. **Kubelet starts containers.** That node’s Kubelet Watches “Pods assigned to this node” on the API Server and asks the Container Runtime to run containers. Results go back through the API Server into etcd. This is where Pod status moves toward Running.

The key is that processes do not call each other directly at each step. What they read and write is always **shared state through the API Server** (final storage in etcd). The **event-driven communication** from earlier is the base structure of this sequence.

This sequence covers deploy and start. **kube-proxy**, which delivers traffic, is not part of this first Pod-start sequence.

## 6. High Availability in Kubernetes


<div align="center">

![Kubernetes high availability](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/14-ha.svg)

</div>


In production, if the API and state store live in **only one place**, cluster operations can shake when that place stops. So teams often add **high availability** (HA, High Availability, a setup where partial failure does not stop the whole). Grasping the idea is enough.

You run several API Servers, and users send requests to **one address**. If some fail, the remaining API Servers keep taking requests. etcd that holds state is usually also multi-node (often an odd count such as three). While a **majority** (quorum) remains, reads and writes continue. Worker Nodes below spread Pods across many machines. Think of Control Plane as several machines taking over for one another, not a single host.

## 7. Docker Ops Limits and Kubernetes Commands

In the previous article, we used scenarios to show **manual, repetitive work** when Docker containers die, grow, change, or need to find each other. This section is not a hands-on cluster install or command lab. For each scenario, we briefly show in a table **which commands and declarations** replace the same ops limit in Kubernetes.

The tables use the names **Deployment** and **Service**. For now it is enough to read them as “a declaration that keeps Desired Pod count” and “a stable entry point in front of changing Pods.”

### 7.1 Recovering a Stopped Container


<div align="center">

![Stopped-container recovery comparison](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/16-scenario-recovery.svg)

</div>


In the previous article, stopping a container meant a person had to press `docker start` again.


| Docker only                                                 | Kubernetes                                                    |
| ----------------------------------------------------------- | ------------------------------------------------------------- |
| `docker stop web-server-1` `docker start web-server-1`     | `kubectl delete pod <pod-name>` `kubectl get pods -l app=web` |
| **Limit:** By default there is no auto-recovery; the service stays empty until a person revives it | **Improvement:** If Desired Pod replica count remains, the platform restores Pod count |


### 7.2 Scaling Out Container Count


<div align="center">

![Container scale-out comparison](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/17-scenario-scale.svg)

</div>


In the previous article, each scale-up meant choosing names and ports by hand and also editing the frontend list.


| Docker only                                                                                                                                   | Kubernetes                                                                |
| --------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `docker run -d --name web-server-5 -p 8084:80 nginx:latest` `docker run -d --name web-server-6 -p 8085:80 nginx:latest` … (repeat per container count and port) | `kubectl scale deployment web --replicas=5` `kubectl get pods -l app=web` |
| **Limit:** A person must avoid port clashes and also edit the frontend server list                                                            | **Improvement:** You only declare Pod replica count; no need to memorize ports |


### 7.3 Updating Container Image Version


<div align="center">

![Container image version update comparison](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/18-scenario-update.svg)

</div>


In the previous article, you repeated stop / rm / run per container.


| Docker only                                                                                                                  | Kubernetes                                                                                                                        |
| ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `docker stop web-server-1` `docker rm web-server-1` `docker run -d --name web-server-1 -p 8080:80 nginx:1.25` … (repeat per container) | `kubectl set image deployment/web nginx=nginx:1.25` `kubectl rollout status deployment/web` `kubectl rollout undo deployment/web` |
| **Limit:** Update and rollback scatter per container, and mid-flight partial outages are easy                                 | **Improvement:** Reflect the image in the manifest, reconcile Pods in turn, and use undo to return near the prior config          |


### 7.4 Load Balancing and Finding Services by Name


<div align="center">

![Load balancing and service discovery comparison](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/19-scenario-service.svg)

</div>


In the previous article, you listed frontend targets or managed container IPs by hand.


| Docker only                                                                      | Kubernetes                                                                       |
| -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| List `host:8080` … `host:8083` in the frontend server list and restart; use `docker inspect` for IPs and write them into app config | `kubectl expose deployment web --port=80 --type=ClusterIP` `kubectl get svc web` |
| **Limit:** Edit config whenever containers grow or shrink; connections break when IPs change | **Improvement:** The Service name stays fixed; the platform keeps the live Pod list current |


### 7.5 Cleaning Up Deployed Containers and Entry Points


<div align="center">

![Cleanup of deployed containers and entry points comparison](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/20-scenario-cleanup.svg)

</div>


| Docker only                                                | Kubernetes                                               |
| ---------------------------------------------------------- | -------------------------------------------------------- |
| Repeat `docker stop …` / `docker rm …` per name; check volumes and networks separately | `kubectl delete deployment web` `kubectl delete svc web` |
| **Limit:** A person tracks leftover containers and ports one by one | **Improvement:** You can remove the whole goal by Deployment and Service units |


What matters here is only that the manual recovery, scale, update, and IP management from the previous article become **commands where the platform follows a declared goal**.

## Before Moving to the Next Article

Here is what this article covered. Starting from Docker-only ops limits, Kubernetes emerged for container orchestration, with declarative style, Control Loops, and Watch-based communication at the design core. API and cluster, Control Plane and Worker Node mesh so a declaration becomes a running Pod, and we sketched in tables how the same ops limits map to commands.
In the next article, we organize the core resources you handle when operating a service—centered on Pod, Deployment, Service, Ingress, and Namespace.
