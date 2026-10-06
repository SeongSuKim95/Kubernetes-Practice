<!--
  Publication copy for GitHub Flavored Markdown; images use GitHub raw URLs.
  Source: 04-pod-lifecycle-and-self-healing.draft.md
-->

# Chap04. Pod State Management and Self-Healing: From Creation to Termination

> This is the fourth article in a 15-week series. We explore Pod creation and execution, status checks, probes, failure recovery, and graceful termination. We finish with examples of diagnosing problems through status information and logs.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/01-k8s-logo.svg)

Creating a Pod is only the beginning of running an application. We need to check whether its containers are ready to handle requests, restart containers or create replacement Pods when failures occur, and allow ongoing work to finish when a Pod is deleted. Checking current state and controlling resources to maintain their declared state is central to Kubernetes.

Chapter 3 introduced Pods and the workload resources that manage groups of Pods. This chapter follows the **lifecycle** of a Pod managed by a Deployment: its creation, execution, and termination. A Deployment does not handle this process alone. Controllers, the Scheduler, and the Kubelet each perform a different part of managing Pod state.

We start with Pod creation, Node assignment, and container execution. We then distinguish running state from readiness to handle requests and examine how probes check application health. Next come failure recovery and graceful termination after a deletion request. Finally, we use status information and logs to identify what prevents a Pod from running. The chapter focuses on these basic operations and diagnostic methods.

## 1. Components Responsible for Pod Creation and Execution

### 1.1 Locations and Roles of Cluster Components

![API Server, controllers, and Scheduler on the control plane, and Kubelet and Pods on a worker](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/13-component-locations.svg)

The diagram uses one control plane Node and one worker Node to show where components run. The **control plane** is the set of components that manages the cluster. These components run on control plane Nodes, sometimes called master Nodes.

- **API Server**: Accepts requests to create, read, and update resources and lets components share declarations and status.
- **Controller**: Compares desired state with actual state and works to close the gap. The control plane's controller manager (`kube-controller-manager`) runs built-in controllers, including the Deployment Controller and ReplicaSet Controller.
- **Scheduler**: Checks the requirements of Pods that have no assigned Node and selects a Node on which each can run.
- **Worker Node**: Runs application containers. Its Kubelet and container runtime handle execution of assigned Pods.
- **Kubelet**: An agent on each Node that observes assigned Pods and manages container execution, health checks, and termination.
- **Container runtime**: Software that prepares images and actually starts and stops container processes.
- **etcd**: The store in which the API Server persists resource declarations and status.

The diagram includes only the components needed to understand Pod creation and execution. [[1]](#ref-1)

### 1.2 From Pod Creation to Container Execution

![Pod creation, Node assignment, container execution, deletion, and replica recovery](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/12-pod-creation-and-replicas.gif)

Fig 3 follows a Deployment that runs three Pods and restores the replica count after one Pod is deleted. The blue row counts Pod objects still recorded in the API. The green row counts Pods whose containers are running on a worker Node. Each Pod in this example has one container.

When a user declares a Deployment with `kubectl apply`, the API Server accepts the request and stores the declaration in etcd. A successful command means the declaration was applied; it does not guarantee that the containers have started. When the user queries Pod status, `kubectl` also sends its request to the API Server.

The Deployment Controller reads the Deployment recorded in the API and manages a ReplicaSet that matches the declaration. In this example, the required ReplicaSet does not yet exist, so the controller requests its creation. The ReplicaSet Controller compares the desired three replicas with the Pods it currently manages, then asks the API Server to create the missing Pods A, B, and C. Deployments and ReplicaSets are resources stored in the API; controllers are the processes that act on those declarations.

At this point, the new Pods are API objects. Each must be assigned a Node before its containers can run. The Scheduler checks resource requests and placement constraints, selects a suitable Node, and records the assignment in the API. This process is called **scheduling**. If no Node satisfies the requirements, the Pod waits. Declaring three replicas does not guarantee placement on three different Nodes.

The Kubelet on the selected Node observes the Pod assigned to it through the API. It prepares the execution environment and asks the runtime to start the containers. The runtime prepares the images and runs the containers. The Kubelet continues checking container state and application health, reporting Pod status to the API. Each component acts on declarations and status in the API; controllers and the Scheduler do not send execution commands directly to the Kubelet.

The request to delete Pod C also goes through the API Server. Recording a deletion request does not immediately remove the Pod object or its containers. The Kubelet observes the request and asks the runtime to stop the containers. Status reporting and a final deletion request follow before the API object is removed. The animation keeps Pod C visible while it is terminating and distinguishes container shutdown from API object removal. [[2]](#ref-2)

The ReplicaSet Controller keeps comparing the desired replica count with the number of active Pods. Terminating and completed Pods do not count as active replicas, so it can create Pod D as soon as Pod C begins deletion. Pod D goes through scheduling, the Kubelet's execution request, and runtime startup in turn. Kubernetes does not revive Pod C or move it to another Node.

To distinguish these roles, the animation shows Pod C stopping and being removed before Pod D is created. In practice, replacement creation can start before Pod C finishes terminating, and each Pod may be scheduled and started at a different time. The animation omits readiness checks and termination grace-period details.

## 2. Pod Running State and Readiness

A Pod appearing in a list does not establish that its application is working. We need to distinguish containers waiting to start, containers running but unable to accept requests, and containers that repeatedly exit. Status commands and their output help reveal those differences.

The following examples assume three Pods labeled `app: web` are visible with the current `kubectl` configuration. The output illustrates the fields; it was not collected from a live cluster. Use your own Pod names and labels when running the commands.

![Kubelet status reporting, API storage, and kubectl list and detail queries](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/14-pod-status-query.gif)

Fig 4 shows how Pod status becomes command output. The Kubelet reports the state it observes to the API Server. When the user requests status, `kubectl` reads information stored in the API and formats the response for that command. These queries do not connect directly to the Pod or ask the Kubelet to run a fresh health check.

The animation shows the `get pods` list, output selecting `status.phase`, and details from `describe pod`. Status reporting repeats independently of user queries; the output reflects status already recorded in the API. The worker Node in the diagram is simplified, while the sample output includes Pods assigned to different Nodes and one awaiting assignment.

### 2.1 Running State and Readiness in the Pod List

Start with `get pods`. The `-l app=web` option selects Pods with that label, and `-o wide` includes additional information such as Pod IPs and Nodes.

```bash
# List readiness, restart counts, and assigned Nodes for web Pods
kubectl get pods -l app=web -o wide
```

```text
NAME                   READY   STATUS    RESTARTS   AGE   IP           NODE
web-7c8d9f6b5d-a1b2c    1/1     Running   0          5m    10.244.1.8   worker-1
web-7c8d9f6b5d-d3e4f    0/1     Running   0          5m    10.244.2.9   worker-2
web-7c8d9f6b5d-g5h6j    0/1     Pending   0          20s   <none>       <none>
```

This example includes only the main columns.

- `READY`: Ready containers out of the total container count. Compare `1/1` with `0/1` to check readiness.
- `STATUS`: A summary of running state or an error reason. `Running` does not mean the application is ready.
- `NODE`: The assigned Node. `<none>` indicates that no Node has been assigned yet.

The name identifies the Pod for a detailed query. Other columns show restart counts, age, and addresses. Here, the main distinction is between running and being ready.

The second Pod is `Running` but has `READY` set to `0/1`: execution and readiness are separate states. The third has `NODE` set to `<none>` and is waiting for assignment. A Pod downloading an image after Node assignment can also be `Pending`, however, so the `STATUS` column alone does not establish the cause.

### 2.2 Pod Phase and Container State

A **Pod phase**, recorded in `status.phase`, summarizes the Pod's lifecycle. Because the list's `STATUS` column can also display error reasons, query the field directly when you need the phase stored in the API.

```bash
# Show each Pod's API phase in a separate column
kubectl get pods -l app=web -o custom-columns='NAME:.metadata.name,PHASE:.status.phase'
```

```text
NAME                   PHASE
web-7c8d9f6b5d-a1b2c    Running
web-7c8d9f6b5d-d3e4f    Running
web-7c8d9f6b5d-g5h6j    Pending
```

This command displays `.status.phase` in the `PHASE` column.

- `PHASE: Running`: The Pod has been assigned to a Node, all containers have been created, and at least one is running, starting, or restarting. This includes Pods that are not yet ready, such as the second Pod.
- `PHASE: Pending`: The Pod is waiting for preparation such as Node assignment or image downloads.

The Pod phase summarizes the whole Pod, while **container state** describes an individual container. A container waiting to restart can be `Waiting` even when the Pod phase is `Running`. In the default list, `CrashLoopBackOff` indicates a restart backoff and `Terminating` indicates deletion in progress; neither is a Pod phase. The official documentation defines all phases. [[3]](#ref-3)

### 2.3 Detailed Readiness and Event Information

Inspect the second Pod to find out why it is `Running` but `0/1`.

```bash
# Inspect container status and events for a running but unready Pod
kubectl describe pod web-7c8d9f6b5d-d3e4f
```

```text
Name:         web-7c8d9f6b5d-d3e4f
Node:         worker-2/192.168.1.12
Status:       Running
Containers:
  web:
    State:          Running
    Ready:          False
    Restart Count:  0
Conditions:
  Type              Status
  PodScheduled      True
  Initialized       True
  ContainersReady   False
  Ready             False
Events:
  Type     Reason     Age                From     Message
  Warning  Unhealthy  5s (x3 over 15s)    kubelet  Readiness probe failed: HTTP probe failed with statuscode: 503
```

Only relevant fields are shown. Read execution state, readiness, and failure information together.

- `State: Running` and container `Ready: False`: The process is running, but it is not ready to accept requests.
- `Ready: False` under `Conditions`: The Pod as a whole is not ready either. A **Pod condition** records whether a particular requirement is satisfied.
- `Message` under `Events`: The readiness check failed with HTTP 503. **Events** record changes and their reasons; here, `kubelet` reported the failed check.

The name and Node identify the resource being inspected. Connect the three findings above before focusing on other conditions or event timing.

This Pod has a Node assignment and a running container, but its readiness check failed. That differs from a Pod that cannot be scheduled or a container that has exited. Events can expire, so check recent records while the problem is occurring. Section 3 explains the separate paths the Kubelet uses to check running state and readiness.

## 3. Application Health Checks in a Running Pod

Section 2 showed how to query status reported to the API. Now we examine how the Kubelet obtains that information. It checks the runtime for container process state and uses probes to inspect application health. Knowing that a container is running does not establish that it can handle requests.

A **probe** is a check the Kubelet performs on a container's application. The user declares the check path, interval, and failure criteria in the Pod configuration. The Kubelet performs the checks and, depending on the probe type, changes readiness or restarts the container.

### 3.1 Probe Declarations in a Pod Template

The following is part of a Deployment's Pod template. `my-web:1.0` is an example image whose application is assumed to expose three health-check paths on port 8080. This is not a complete deployment file to run as-is; it shows where probes are declared for a container.

```yaml
# Declare three HTTP health checks in a Deployment Pod template
spec:
  template:
    spec:
      containers:
      - name: web
        image: my-web:1.0
        startupProbe:  # Gate the other two probes until startup succeeds
          httpGet:  # Check an HTTP endpoint on the Pod
            path: /startup  # Startup check endpoint
            port: 8080  # Port receiving probe requests
          periodSeconds: 5  # Check every 5 seconds
          timeoutSeconds: 2  # Wait up to 2 seconds for a response
          failureThreshold: 30  # Fail after 30 consecutive failures
        readinessProbe:  # Check readiness to receive requests
          httpGet:  # Check an HTTP endpoint on the Pod
            path: /ready  # Readiness check endpoint
            port: 8080  # Port receiving probe requests
          periodSeconds: 5  # Check every 5 seconds
          timeoutSeconds: 2  # Wait up to 2 seconds for a response
          failureThreshold: 3  # Fail after 3 consecutive failures
        livenessProbe:  # Check for a failure requiring a restart
          httpGet:  # Check an HTTP endpoint on the Pod
            path: /healthz  # Liveness check endpoint
            port: 8080  # Port receiving probe requests
          periodSeconds: 10  # Check every 10 seconds
          timeoutSeconds: 2  # Wait up to 2 seconds for a response
          failureThreshold: 3  # Fail after 3 consecutive failures
```

- `startupProbe`: Checks startup completion. Readiness and liveness checks do not begin until it succeeds.
- `readinessProbe`: Checks readiness to accept requests and updates readiness when it fails.
- `livenessProbe`: Detects a failure requiring restart. On failure, the container is stopped and its restart policy applies.
- `httpGet.path` and `httpGet.port`: The HTTP path and port to check on the Pod. These probes use `/startup`, `/ready`, and `/healthz`, all on port 8080.
- `periodSeconds` and `timeoutSeconds`: The interval between checks and the response timeout for one check.
- `failureThreshold`: The number of consecutive failures required to declare failure: 30 for startup and 3 for the other probes.

This fragment assumes a `web` container using `my-web:1.0`, which provides the three endpoints. The omitted `successThreshold` uses its default value of 1.

The Kubelet normally sends HTTP checks to the specified port on the Pod IP and treats response codes from 200 through 399 as success. Writing a path in YAML does not create a health endpoint: the application must return responses appropriate to each check. Readiness checks may run more frequently than the configured interval while the container is not ready. [[4]](#ref-4)

![Runtime state checks and the startup, readiness, and liveness HTTP probe paths](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/15-runtime-and-probe-status.gif)

Fig 5 distinguishes runtime state checks from the three HTTP probes. Blue arrows show the Kubelet checking container execution through the runtime. Purple arrows show HTTP probes sent to port 8080 on the Pod IP. The probe stages and paths are:

- **Stage 1: `startupProbe`, `/startup`**: Checks application startup completion. Readiness and liveness checks begin after it succeeds.
- **Stage 2: `readinessProbe`, `/ready`**: Repeatedly checks whether the application can currently handle requests. Reaching the failure threshold changes readiness to `False` while the container keeps running.
- **Stage 2: `livenessProbe`, `/healthz`**: Repeatedly checks whether the container needs restarting. Reaching the failure threshold causes termination, after which the restart policy applies.

`readinessProbe` and `livenessProbe` are not consecutive stages in which one must succeed before the other runs. Both repeat independently after startup succeeds. The animation presents readiness failure followed by liveness failure to illustrate their different effects. In this example, three consecutive readiness failures leave the container running. Three subsequent liveness failures cause the container to restart in the same Pod under the `Always` policy. The new container execution begins with its startup probe again.

After readiness failure alone, the Pod can appear as `Running` with `READY` set to `0/1`, as in Section 2. HTTP probes go directly from the Kubelet to the Pod. Their path differs from an exec probe, which runs a command inside the container through the runtime.

![Startup success followed by independent readiness and liveness checks](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/16-probes-at-a-glance.svg)

Fig 6 summarizes the same sequence. Once Stage 1, `startupProbe`, succeeds, the two Stage 2 checks, `readinessProbe` and `livenessProbe`, repeat independently. Readiness determines whether the application can accept requests; liveness determines whether the container needs restarting. The Pods in this diagram represent different check scenarios for the same Pod, not separate replicas.

### 3.2 Startup Probes Before Initialization Completes

As in Stage 1 of Fig 6, a **startup probe** checks whether the application has finished starting while it loads initial data. With the manifest above, the Kubelet sends requests to `/startup`. If the application returns 503 during initialization and 200 when ready to start, the first 200 response establishes startup success.

Until the startup probe succeeds, readiness and liveness checks for that container do not begin. This prevents a slow-starting application from repeatedly being terminated because of liveness failures. After startup succeeds once, the startup check ends for that container execution, and readiness and liveness checks run independently.

In this configuration, the Kubelet keeps checking startup until the failure count reaches 30. Thirty consecutive failures cause it to stop the container and apply the restart policy. With the usual `Always` policy for Deployment Pods, the container restarts in the same Pod and its startup probe runs again. Set the interval and failure threshold with the application's normal startup time in mind.

### 3.3 Readiness Probes for Accepting Requests

The `readinessProbe` portion of Fig 6 shows a running application that is not ready for new requests. A **readiness probe** tests whether the application can accept them. For example, an initialized application unable to connect to a required external system could return 503 from `/ready`. In this configuration, three consecutive failures change the container's readiness to `False` and the Pod's `Ready` condition to `False`. This is the `Running` but `0/1` situation from Section 2.

In a configuration that distributes requests among Pods, readiness determines which Pods can receive new requests. An unready Pod is removed from the eligible targets, and ready Pods handle the requests. The readiness status reported by the Kubelet provides the basis for that selection.

A readiness failure alone does not restart the container or replace the Pod. The Kubelet continues checking the same container. In this example, if `/ready` returns 200 again and other readiness conditions are satisfied, the same Pod can become a request target again. When an external system is briefly unavailable, readiness checks can keep new requests away while the application recovers.

A readiness change does not immediately disconnect existing connections or block every request sent directly to the Pod IP. Omitting a readiness probe also does not let Kubernetes infer when application data has finished loading. If the application needs preparation time after container startup, declare that requirement through a readiness probe.

### 3.4 Liveness Probes for an Unresponsive Application

The `livenessProbe` portion of Fig 6 represents an application whose process is running but cannot respond. A **liveness probe** detects a condition that requires a container restart. The container can still be `Running` while failing to respond to `/healthz`.

In the example, the Kubelet checks every 10 seconds and counts a failure if no response arrives within 2 seconds. After three consecutive failures, it stops the container. Under the Deployment's `Always` policy, it uses the runtime to start a new container in the same Pod. Once the new container's startup probe succeeds, readiness and liveness checks resume. Readiness results determine whether the application can accept requests.

Readiness and liveness checks repeat independently after startup succeeds. They do not run in a sequence requiring readiness to succeed first. Treating a temporary external database outage as a liveness failure can cause unnecessary restarts across many containers. Liveness criteria should identify problems a container restart can resolve.

Besides HTTP, probes can test a TCP port connection or execute a command inside the container and check for exit code 0. Whatever the mechanism, first establish separate criteria for readiness and the need to restart.

## 4. Pod Failures and Self-Healing

Suppose a Deployment runs three Pods for a web application. We will distinguish two situations that require recovery: **a failure inside a Pod** and **a Node failure**. Here, a Pod failure means that its application container exits or stops responding while the Node itself remains healthy.

- **Pod failure**: The Kubelet on the healthy Node restarts the container within the same Pod.
- **Node failure**: If the Node remains unavailable, controllers in the Control Plane create a replacement Pod, and the Scheduler assigns it to another Node.

The key distinction is whether a container restarts in the same Pod or a new Pod starts on another Node. A readiness check failure alone triggers neither a container restart nor Pod replacement; checks continue to determine when the application can receive requests again.

![Container restart and replacement Pod scheduling across two Worker Nodes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/17-node-failure-recovery.gif)

Fig 7 shows Pod A, Pod B, and Pod C distributed across two Worker Nodes. In the first situation, the Kubelet on Worker Node 1 detects that Pod A's container has exited and asks the runtime to restart it. Pod A and its unique identifier, **UID**, remain unchanged in the Control Plane; only the container process starts again. The Scheduler does not select another Node.

In the second situation, Worker Node 1 stops sending heartbeats. If the failure persists, removal of its Pods begins. The ReplicaSet Controller requests a new Pod D to replace the missing replica. The Scheduler excludes the `NotReady` Worker Node 1 and selects Worker Node 2, which meets the Pod's requirements. Its Kubelet and runtime start Pod D's container from scratch. Kubernetes creates a separate Pod D; it does not move Pod A to another Node.

### 4.1 Pod Failure and Container Restart Within the Same Pod

Suppose the `web` container in one of the three Pods exits because of an application error. The Pod object and Node still exist. The Kubelet detects the exit and asks the runtime to start the container again according to the Pod's restart policy. There is no need to create another Pod or select a Node again.

A **restart policy** specifies when an exited container should run again. Pods in a typical Deployment use `restartPolicy: Always`, so their containers restart regardless of why they exited. For standalone Pods and other applicable workloads, `OnFailure` restarts a container only after a failure, while `Never` prevents a restart. The Deployment examples in this chapter use `Always`.

The following example shows a container that has restarted once and is ready to receive requests again.

```bash
# Check Pod name, readiness, and restart count after a restart
kubectl get pod web-7c8d9f6b5d-a1b2c
```

```text
NAME                   READY   STATUS    RESTARTS      AGE
web-7c8d9f6b5d-a1b2c    1/1     Running   1 (20s ago)   8m
```

The Pod name stays the same, while `RESTARTS` increases from 0 to 1. `AGE` measures time since the Pod was created, so a container restart does not reset it. `1/1` means the new container is ready; it may briefly show `0/1` during initialization.

The Pod's UID also stays the same, and its IP normally remains unchanged during a container restart. However, the new container process does not inherit the old process's memory. The application must initialize again and reestablish its external connections.

Even if the container has not exited, reaching the liveness failure threshold causes the Kubelet to stop and restart it. A readiness failure instead helps determine whether new requests should be sent to the Pod. `READY: 0/1` alone does not mean the container will restart.

### 4.2 Node Failure and a New Pod on Another Node

If a Worker Node shuts down, its Kubelet cannot restart containers. The Control Plane monitors Node status and periodic heartbeats. Missing a heartbeat does not immediately cause every Pod to be replaced: temporary communication failures are possible, so failure detection and Pod removal involve waiting periods.

```bash
# Check Node availability during a Node failure
kubectl get nodes
```

```text
NAME       STATUS     ROLES    AGE   VERSION
worker-1   NotReady   <none>   10d   v1.34.0
worker-2   Ready      <none>   10d   v1.34.0
```

This output illustrates a Node failure. The Control Plane may be unable to verify the current state of containers on the `NotReady` Node. If only communication has failed, processes might still be running there. `NotReady` alone does not prove that all of the Node's containers have stopped.

When the failure persists and removal of the Node's Pods begins, the ReplicaSet Controller can create replacement Pods. The Scheduler selects a suitable available Node. If `worker-2` has enough resources, it can run the new container. Kubernetes does not transfer the original Pod or its memory to another Node; it creates a new Pod and starts the application again. [[5]](#ref-5)

If other Nodes lack CPU or memory, the new Pod waits in `Pending`. Applications that need storage may also need time to attach it. Even with Deployment-managed replicas, recovery takes time, and requests may fail in the meantime. Spreading replicas across Nodes and keeping spare capacity allows the remaining Pods to handle requests when one Node fails.

### 4.3 Replacement Pod Creation After Pod Deletion

Deleting a Pod directly is another way to observe replacement by a controller. Here, we delete one Pod from a practice Deployment. Since the existing Pod object is being removed, restarting its container cannot restore the replica count. The ReplicaSet Controller sees the difference between three desired replicas and two remaining active replicas, then creates a new Pod from the same template.

The following command deletes one Pod in a practice Deployment. Substitute a Pod name from your own practice environment.

```bash
# Delete a practice Deployment Pod to observe replacement
kubectl delete pod web-7c8d9f6b5d-a1b2c
kubectl get pods -l app=web
```

```text
pod "web-7c8d9f6b5d-a1b2c" deleted
NAME                   READY   STATUS              RESTARTS   AGE
web-7c8d9f6b5d-d3e4f    1/1     Running             0          10m
web-7c8d9f6b5d-g5h6j    1/1     Running             0          10m
web-7c8d9f6b5d-k7m8n    0/1     ContainerCreating   0          2s
```

This example assumes the other two Pods are running normally. The original Pod has disappeared, and a new one ending in `k7m8n` has appeared. Its `AGE` is two seconds, and `RESTARTS` starts at zero; it does not inherit the old Pod's restart history. The new Pod gets a different UID, and its IP may also change.

The Scheduler assigns the new Pod to a Node, and that Node's Kubelet starts its containers. Image preparation, application initialization, and readiness checks must complete before it can receive requests. Having three Pod objects again therefore does not necessarily mean three replicas can handle requests. A `Terminating` Pod and its replacement may also appear together briefly.

A ReplicaSet does not simply count ready Pods and create more whenever that count falls. If all three Pods are still managed by the ReplicaSet, one Pod failing its readiness check does not by itself cause a fourth Pod to be created. Conversely, deleting a standalone Pod with no managing controller does not automatically create a replacement.

### 4.4 Repeated Failures and the Limits of Self-Healing

If a container exits on every startup because a required setting is missing, restarting it with the same configuration produces the same error. Kubernetes can retry execution, but it cannot supply the missing value automatically. Recovery attempts and fixing the underlying cause are separate tasks.

Repeated exits introduce **backoff**, a delay between retries. `CrashLoopBackOff` does not mean Kubernetes has abandoned recovery; it means the container is waiting for another restart after repeated failures. Inspect the previous container's termination reason and logs, then correct the application's configuration or code.

Check readiness as well as the Pod count when assessing recovery. An increase in `RESTARTS` for the same Pod indicates a container restart, while a changed name and UID identify a replacement Pod. Then check the `Ready` condition and actual application responses to confirm that request handling has recovered.

## 5. Graceful Pod Termination

A Pod deletion request does not make its running processes disappear immediately. Kubernetes allows time for the application to finish in-flight requests or file writes.

After observing the Pod's deletion state, the Kubelet asks the container runtime to stop its containers. The application typically receives SIGTERM, a request to shut down gracefully, and begins cleaning up. The **termination grace period** allows time for this work; `terminationGracePeriodSeconds` defaults to 30 seconds. Processes that remain after the grace period are forcibly terminated. [[2]](#ref-2)

Network updates that remove a terminating Pod from the targets for new connections happen alongside container shutdown. The ReplicaSet can also create a replacement before the old Pod finishes terminating, so both may appear briefly during replacement.

Deleting one Deployment-managed Pod causes the ReplicaSet to restore the replica count. Deleting the Deployment itself in the usual way also removes its ReplicaSets and Pods. Replacing one Pod and removing the entire application deployment are different operations.

## 6. Failure Diagnosis Through Pod Status and Logs

If repeated recovery attempts do not restore the application, the cause needs to be identified and fixed. Pod status and events show where the process is failing; container logs show errors reported by the application.

We will first identify an affected Pod, then investigate two common situations. For `CrashLoopBackOff`, we inspect the logs from the previous container execution. For a Pod stuck in `Pending`, we check Node assignment and events. The outputs illustrate how to read these states; names, times, and restart counts vary by environment.

### 6.1 Pod Status and Identification of Affected Pods

When requests fail, first check whether the Pods exist and their containers are ready. An increasing `RESTARTS` count calls for investigation into repeated container exits. `READY` shows ready containers out of the total container count; also check the Pod's `Ready` condition in its detailed status.

```bash
# Check web Pod readiness and container restart counts
kubectl get pods -l app=web
```

```text
NAME                   READY   STATUS             RESTARTS   AGE
web-7c8d9f6b5d-a1b2c    0/1     CrashLoopBackOff   4          4m
web-7c8d9f6b5d-d3e4f    1/1     Running            0          4m
web-7c8d9f6b5d-g5h6j    1/1     Running            0          4m
```

All three Pods exist in this example, but the first Pod's container keeps exiting. Maintaining the desired replica count does not guarantee that every replica can handle requests.

### 6.2 Common Failure: Repeated Container Exits

The first Pod in Section 6.1 shows `CrashLoopBackOff`: its container repeatedly exits after starting. The detailed view provides its termination reason and recent events.

```bash
# Inspect termination reasons and recent events for a crashing container
kubectl describe pod web-7c8d9f6b5d-a1b2c
```

```text
Containers:
  web:
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
    Ready:          False
    Restart Count:  4
Events:
  Type     Reason   Message
  Warning  BackOff  Back-off restarting failed container web in pod ...
```

This excerpt includes only container status and events. Exit code 1 tells us the previous execution failed, but not why. The previous container's logs can show the application's error message.

```bash
# Read error logs from the previous web container execution
kubectl logs web-7c8d9f6b5d-a1b2c -c web --previous
```

```text
ERROR: required environment variable DATABASE_HOST is missing
```

Here, a required environment variable is missing. Update the Deployment's Pod template so the application receives `DATABASE_HOST`. Keeping the restart policy or repeatedly deleting the Pod will not restore a missing setting. `--previous` requests logs from the immediately preceding container execution; use `-c` to select a container when the Pod contains more than one.

### 6.3 Common Failure: A Pod Stuck in Pending

![Kubelets report Node status to the API Server, and the Scheduler records a failed assignment after comparing remaining memory](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/18-pod-pending.gif)

Now consider a separate case in which a Pod remains `Pending` because preparation for running its containers cannot complete. A brief `Pending` phase is normal during creation, but a persistent one warrants investigation. Suppose the new Pod's container requests 4 GiB of memory. All other requirements are met, but Worker Node 1 has only 1 GiB left to assign to new Pods, and Worker Node 2 has 2 GiB.

The new Pod needs all 4 GiB on a single Node. Neither Node can satisfy that request, so the Pod waits for assignment. “Remaining memory” in the figure is the amount available for new Pod requests after accounting for system reservations and existing Pod requests, not a snapshot of actual memory usage.

In Fig 8, each Kubelet reports its Node's resources and status to the API Server. The Scheduler reads Node information and Pod declarations through the API Server and accounts for existing Pod requests to calculate the remaining memory. Kubelets do not send this calculation directly to the Scheduler.

If the Scheduler cannot find a suitable Node, it records a scheduling failure through the API. Normally, the Kubelet observes a Pod assigned to its Node and asks the runtime to start its containers. Here, no Node has been assigned, so no arrow shows a Kubelet starting the new Pod, and the Pod remains `Pending`.

The following outputs illustrate this situation; actual names and times vary by environment.

```bash
# Check status and Node assignment for a waiting Pod
kubectl get pod web-7c8d9f6b5d-g5h6j -o wide
```

```text
NAME                   READY   STATUS    RESTARTS   AGE   IP       NODE
web-7c8d9f6b5d-g5h6j    0/1     Pending   0          2m    <none>   <none>
```

- `STATUS: Pending`: Preparation for running the containers is incomplete.
- `NODE: <none>`: The Scheduler has not assigned a Node to this Pod.

The detailed view explains what prevented assignment.

```bash
# Inspect the memory request and scheduling failure event
kubectl describe pod web-7c8d9f6b5d-g5h6j
```

```text
Node:         <none>
Status:       Pending
Containers:
  web:
    Requests:
      memory:  4Gi
Conditions:
  Type           Status
  PodScheduled   False
Events:
  Type     Reason            From               Message
  Warning  FailedScheduling  default-scheduler  0/2 nodes are available: 2 Insufficient memory.
```

This excerpt includes only the relevant fields and event message.

- `Requests.memory: 4Gi`: The container requests 4 GiB of memory.
- `2 Insufficient memory` in the `FailedScheduling` event: Neither Node can satisfy the memory request.

To resolve this, review the application's memory requirements and reduce an excessive request, or provide a Node with enough capacity. Deleting and recreating the Pod with the same request repeats the scheduling failure. [[6]](#ref-6)

Even after Node assignment, an incorrect image name or a registry access failure can prevent a container from starting. The Pod phase may remain `Pending` while `kubectl get pods` shows `ErrImagePull` or `ImagePullBackOff` in `STATUS`. Check the image download error in `kubectl describe pod` events, then correct the image name or access configuration. This is why diagnosis requires Node assignment and events as well as the `Pending` phase itself. [[7]](#ref-7)

## Before Moving On

Controllers create Pods, the Scheduler selects Nodes, and Kubelets manage container execution. Running and readiness are different states, so probes check application health. A container failure can be recovered by a restart within the same Pod; a persistent Node failure can lead to a replacement Pod on another Node. Pod termination gives applications time to finish their work. If problems continue, use status, events, and logs to find the cause.

The next chapter explains how a Service provides a stable access point even as Pod names and IPs change. We then compare the access points offered by ClusterIP, NodePort, LoadBalancer, and ExternalName based on the client's location and the connection target.

## References

- <a id="ref-1"></a>[1] [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)
- <a id="ref-2"></a>[2] [Pod Termination](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination)
- <a id="ref-3"></a>[3] [Pod Phase](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase)
- <a id="ref-4"></a>[4] [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- <a id="ref-5"></a>[5] [Node Controller](https://kubernetes.io/docs/concepts/architecture/nodes/#node-controller)
- <a id="ref-6"></a>[6] [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- <a id="ref-7"></a>[7] [Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
