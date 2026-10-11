<!--
  English publication based on 04-pod-lifecycle-and-self-healing.draft.md.
  GitHub Flavored Markdown; figures use GitHub raw URLs.
-->

# Chap04. Pod Execution and Status Checks

> This is the fourth article in a 16-chapter series. We follow Pod creation through container startup, learn how to query status, and examine how startup, readiness, and liveness probes distinguish application conditions.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/01-k8s-logo.svg)

In Chapter 3, we declared an application image and a desired Pod count in a Deployment. After asking for three web servers, the next question is when they can receive requests. One Pod may still be downloading its image, while another has started its container but is loading initial data and cannot yet respond.

Kubernetes assigns declared Pods to Nodes, starts their containers, and continues checking their state. Understanding how controllers, the Scheduler, and the Kubelet carry out that work helps us interpret the status shown in a Pod list.

A running web server process and an application ready to answer requests are different conditions. This chapter follows Pod execution to make that distinction clear, then introduces the checks that tell Kubernetes whether an application is ready or needs a restart.

## 1. Components Responsible for Pod Creation and Execution

Several components work together to turn a Deployment's declared configuration into running containers. To follow that path, we first distinguish cluster management from container execution.

### 1.1 Locations and Roles of Cluster Components

![API Server, controllers, and Scheduler on the control plane, and Kubelet and Pods on a worker](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/13-component-locations.svg)

Running Pods requires both cluster-wide placement decisions and container execution on individual Nodes. The **Control Plane** in Fig 2 is the set of cluster management components running on a Control Plane Node. The Worker Node on the right runs the containers of its assigned Pods. The components have the following roles.

**Components on the Control Plane Node (master node)**

- **API Server**: Receives resource creation, query, and update requests and lets components share declarations and status.
- **Controllers**: Processes that compare desired and actual state and work to reduce the difference. The controller manager (`kube-controller-manager`) runs built-in controllers such as the Deployment Controller and ReplicaSet Controller.
- **Scheduler**: Checks the requirements of unassigned Pods and selects a Node for each one.
- **etcd**: Stores the resource declarations and status written by the API Server.

**Components on a Worker Node**

A Worker Node runs the containers of its assigned Pods. The following components handle that execution.

- **Kubelet**: An agent that reads the Pods assigned to its Node and manages container execution, health checks, and termination.
- **Container runtime**: Software that prepares images and actually starts or stops container processes.

Let's connect these roles through a web application's startup. The user declares a Deployment, which the API Server accepts and stores in etcd. Controllers read the declaration through the API Server and request the necessary Pods. Those Pods need somewhere to run, so the Scheduler selects suitable Worker Nodes and records the assignments through the API Server.

Work then continues on the selected Worker Node. Its Kubelet reads the assigned Pod and asks the runtime to start its containers. The runtime prepares the images and starts them. The Kubelet subsequently reports status to the API Server, and controllers use the reported state to check whether the desired count is maintained. Declarations and status shared through the API Server connect Control Plane decisions with Worker Node execution. [[1]](#ref-1)

### 1.2 From Pod Creation to Container Execution

Now apply that division of work to creating three web Pods. Distinguishing when a Pod is recorded in the API from when its containers actually start makes the path from declaration to execution easier to follow.

![Pod creation, Node assignment, container execution, deletion, and replacement](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/12-pod-creation-and-replicas.gif)

Fig 3 follows a Deployment that runs three Pods and restores the replica count after one Pod is deleted. The blue row counts Pod objects still recorded in the API. The green row counts Pods whose containers are running on a worker Node. Each Pod in this example has one container.

The user runs `kubectl apply` to declare a Pod template and a desired count of three. The API Server accepts and stores the declaration, giving controllers the configuration to act on.

The Deployment Controller observes this declaration and requests a ReplicaSet that maintains three Pods from the template. Deployment and ReplicaSet are resources stored in the API; controllers read their declarations and perform the work. The Namespace introduced in Chapter 3 also applies to the resources created here. If the Deployment belongs to `default`, its ReplicaSet and Pods are created in `default` as well.

Once the ReplicaSet exists, the ReplicaSet Controller compares the desired count of three with the current count of zero Pod objects. It asks the API Server to create Pods A, B, and C. Pod objects now exist in the API, but a Node must be assigned before their containers can run.

The Scheduler checks each unassigned Pod's resource requests and placement constraints, selects an eligible Node, and records the assignment in the API. This is **scheduling**. If no Node meets the requirements, the Pod waits. Multiple Pods may also be assigned to the same Node.

The selected Node's Kubelet reads its assigned Pods through the API. It prepares the execution environment and asks the runtime to start the containers. The runtime prepares the images and starts the containers in Pods A, B, and C, bringing the running Pod count to three.

With all three Pods running, the user requests deletion of Pod C. The API Server marks it for deletion. The Kubelet observes that request through the API and asks the runtime to stop its container. After the termination procedure, Pod C's container stops and the running count falls to two.

The Kubelet reports Pod C's terminated state and requests final removal of its API object. Once the API Server removes it, two Pod objects remain. The figure distinguishes container termination from removal of the Pod object in the API. [[2]](#ref-2)

The ReplicaSet Controller observes that only two Pods remain toward the desired count of three. It requests a new Pod D from the same template to fill the gap.

Pod D follows the same execution path. The Scheduler checks its requirements, selects a Node, and records the assignment. That Node's Kubelet reads the assignment and asks the runtime to start its container. The running Pod count returns to three.

Fig 3 shows Pod D being created after Pod C terminates and is removed. In practice, terminating Pods are excluded from the active count, so replacement creation can begin before Pod C finishes terminating. Assignment and startup also progress separately for each Pod. Even Pods created by the same Deployment therefore need individual status checks.

## 2. Pod Running State and Readiness

The Kubelet reports Pod status to the API after starting its containers. Querying that information tells us whether containers are waiting to run, running, or ready to receive requests. Let's compare three web Pods to see the difference.

The following commands and outputs compare three Pods labeled `app: web` in the `default` Namespace. They assume that `kubectl` also uses `default` as its current Namespace. If the application is deployed elsewhere, use the same `-n` option for both list and detail queries to find its Pods.

![Kubelet status reporting, API storage, and kubectl list and detail queries](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/14-pod-status-query.gif)

Fig 4 follows reported Pod status into command output. State observed on a Worker Node is stored through the API Server, and users query that information.

The Kubelet reports container execution state and readiness check results to the API Server, which stores them in etcd. Subsequent queries read this recorded status. Reporting repeats independently of user queries.

When the user runs `kubectl get pods -l app=web`, `kubectl` asks the API Server for Pods labeled `app=web` in the current Namespace. The API Server returns the Pod information, which `kubectl` formats as a table. Users can compare execution state and readiness across the Pods.

To see only the overall lifecycle phase, select the name and `status.phase` as output fields. `kubectl` extracts the values from the response and displays the phase in a `PHASE` column. This selects a lifecycle summary from the same Pod information.

After finding an unready Pod in the list, use `kubectl describe pod` to request its details and related events. Reading container state, Pod conditions, and events together helps explain why it is not ready.

The single Worker Node in Fig 4 simplifies the layout. The outputs below include Pods on different Nodes as well as a Pod awaiting assignment. We begin with the list, then narrow the investigation to one Pod's details.

### 2.1 Running State and Readiness in the Pod List

Start with `get pods` to compare progress. `-l app=web` selects Pods with that label, while `-o wide` includes additional information such as Pod IP and Node.

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

- `READY`: Ready containers out of the total container count. Compare `1/1` with `0/1` to assess readiness.
- `STATUS`: Summarizes execution state or an error reason. Read it alongside `READY` to assess request readiness.
- `NODE`: The assigned Node. `<none>` means the Pod has not yet been assigned.

The second Pod is `Running` but has `READY` set to `0/1`, showing that execution and request readiness are separate. The third Pod has no assigned `NODE` and is waiting for placement. A Pod downloading an image after assignment can also be `Pending`, so other information is needed to determine its progress. That requires distinguishing the Pod's overall phase from each container's state.

### 2.2 Pod Phase and Container State

The `Running` and `Pending` values summarize overall Pod progress. This lifecycle summary, stored in `status.phase`, is the **Pod phase**. Because the list's `STATUS` column can also show error reasons, query `status.phase` directly when you need the phase recorded in the API.

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

A Pod phase summarizes the whole Pod, while **container state** describes an individual container. A container can be `Waiting` for a restart while the Pod phase remains `Running`. In the default list, `CrashLoopBackOff` indicates a restart backoff and `Terminating` indicates deletion in progress; neither is itself a Pod phase. The official documentation defines all phases. [[3]](#ref-3) Both web Pods above are `Running`, so explaining their different readiness requires container details and check results.

### 2.3 Detailed Readiness and Event Information

`kubectl describe pod` presents container state, readiness, and recent events together. Query the second Pod, shown as `0/1`, to find why it is not ready for requests.

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

This Pod has been assigned to a Node and its container is running, but its readiness check has failed. That distinguishes it from a placement failure or a terminated container. Events can expire, so inspect recent records while investigating a problem. To understand the result, we next need to see what the Kubelet uses as its readiness criterion.

## 3. Application Health Checks in a Running Pod

In the previous example, the web container was running but returned 503 to a readiness check. The Kubelet obtains these two facts through different paths. It asks the runtime whether the container process is running and uses a health check called a **probe** to check the application.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/interaction-pod-health-check-v3.png" alt="A Node uses a stethoscope to check a Pod’s health" width="75%" />

The Node examining the Pod with a stethoscope represents the Kubelet on that Node checking the application inside the Pod. The two checks on the clipboard represent separate checks for startup completion and readiness to handle requests. The green check held by the Pod indicates that it is ready to receive requests.

Applications become ready under different conditions, so users declare check paths, intervals, and failure thresholds in the Pod configuration. The Kubelet uses the results to change readiness or terminate a container that needs a restart.

![Kubelet runtime queries, Pod HTTP checks, and API status reporting within a cluster](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/15-state-check-paths.gif)

In Fig 5, the Kubelet asks the runtime for execution state along the blue path and receives a response. This establishes whether the process is running. It checks application responsiveness by sending an HTTP request to the Pod along the purple path. The application returns HTTP 200, so the check succeeds. The Kubelet reports the observed status to the API Server along the green path, and it is stored in etcd. Checks and status reporting repeat while the container runs.

Execution state and application checks provide different information. For an HTTP check, we must choose a path and define which results mean readiness or failure for that application.

### 3.1 Probe Declarations in a Pod Template

These criteria belong in each container's configuration within the Deployment's Pod template. We will declare separate checks for startup completion, request readiness, and the need for a restart. The following Pod template excerpt assumes the application serves three check paths on port 8080.

```yaml
spec:
  template:
    spec:
      containers:
      - name: web
        image: my-web:1.0
        startupProbe:  # Startup completion
          httpGet:
            path: /startup
            port: 8080
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 30  # Fail after 30 consecutive failures
        readinessProbe:  # Request readiness
          httpGet:
            path: /ready
            port: 8080
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 3
        livenessProbe:  # Need for a restart
          httpGet:
            path: /healthz
            port: 8080
          periodSeconds: 10
          timeoutSeconds: 2
          failureThreshold: 3
```

- `startupProbe`: Checks startup completion. Readiness and liveness checks wait until it succeeds.
- `readinessProbe`: Checks readiness to receive requests and changes readiness when the failure threshold is reached.
- `livenessProbe`: Checks for faults requiring a restart. On failure, the container is terminated and its restart policy applies.
- `httpGet.path` and `httpGet.port`: The HTTP request path and port. The checks use `/startup`, `/ready`, and `/healthz` on port 8080.
- `failureThreshold`: The consecutive failures required to declare failure: 30 for startup and three for the other checks.

`periodSeconds` sets the check interval, and `timeoutSeconds` limits the wait for a response. The Kubelet normally sends the HTTP request to the specified port on the Pod IP and treats status codes from 200 through 399 as success. The application must implement responses appropriate to startup, readiness, and health at those paths. [[4]](#ref-4)

The differences become clearer as the same application initializes, serves requests, and encounters problems. We begin with the check used before startup completes.

### 3.2 Startup Probes Before Initialization Completes

If an application needs time to load initial data, slow responses during startup must be distinguished from faults after startup. A **startup probe** checks whether initialization has finished. Fig 6 follows one Pod through initialization, request handling, readiness changes, and a container restart. It assumes one container per Pod and a configuration that sends new requests to ready Pods.

![Startup, readiness failure and recovery, and a liveness-triggered restart within the same Pod](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/04/en/16-probe-state-changes.gif)

Initially, the container is running but readiness is `False` while the application loads data. It returns 503 to the Kubelet's `/startup` request. When initialization finishes and the response becomes 200, the startup check succeeds and readiness and liveness checks begin. Fig 6 compresses the intervals to compare state changes; actual checks repeat independently according to their configuration.

Delaying readiness and liveness checks during initialization prevents a normally slow-starting application from being repeatedly terminated by liveness failures. Once the startup check succeeds, it does not run again during that container execution.

With this configuration, the Kubelet keeps checking until startup succeeds or failures reach 30. After 30 consecutive failures, it terminates the container and applies the restart policy. Under the `Always` policy used by Deployments, the container starts again in the same Pod and startup checking resumes. Choose the interval and failure threshold to allow normal startup time. Once startup finishes, request readiness still needs ongoing checks.

### 3.3 Readiness Probes for Accepting Requests

A **readiness probe** checks whether an application that has completed startup can handle requests. In Fig 6's Serving requests scene, the application returns 200 to `/ready`. The status row shows `Ready: True` and includes the Pod among targets for new requests. The web Pod is ready to serve traffic.

Now suppose the application temporarily loses contact with an external system needed to handle requests. It is still running but returns 503 from `/ready` because it cannot process requests normally. In the Temporary readiness failure scene in Fig 6, consecutive failures accumulate. When they reach the configured threshold of three, `Ready` becomes `False`.

The Kubelet reports this result to the API Server along the green arrow. Once the readiness change is reflected in request routing, the Pod is excluded from targets for new requests. When several Pods run the application, other ready Pods can handle those requests.

Meanwhile, `/healthz` keeps returning 200 and the container restart count remains zero. The container continues running while the connection to the external system recovers. The Kubelet keeps checking `/ready`; when it returns 200 again, readiness becomes `True` in this example. The same Pod resumes receiving requests in Fig 6's Back in request targets scene.

Readiness checks allow an application to recover while temporarily receiving no new requests. If its internal processing has stopped and waiting cannot resolve the problem, however, restarting the container may be necessary.

### 3.4 Liveness Probes for an Unresponsive Application

After readiness recovers, Fig 6 moves to the Application unresponsive scene. The container is still running, but now `/healthz` also fails to respond. A **liveness probe** determines whether the container needs a restart in this situation.

When an HTTP request travels along the purple path but no response returns, the figure shows Response timeout. This configuration checks every 10 seconds and counts a failure if no response arrives within two seconds. After three consecutive failures, the Kubelet terminates the container and applies its restart policy. In this example, `/ready` also stops responding, so readiness fails and the Pod is excluded from new request targets.

The orange arrow then leads from the Kubelet to the runtime. The Kubelet requests termination and a restart under the `Always` policy, and the runtime starts a new container in the same Pod. The Pod remains in place in Fig 6, while its container restart count changes from zero to one.

The new container needs to initialize, so the Kubelet starts again with `/startup`. After that succeeds, readiness and liveness checks resume independently. When `/ready` succeeds, `Ready` becomes `True` and the Pod receives requests again in the final Serving requests again scene.

During the readiness failure, the container kept running while the application recovered. Here, recovery involved starting a new container. Liveness criteria should therefore target problems that a restart can resolve. Treating a temporary external database outage as a liveness failure can repeatedly restart containers when waiting would have allowed recovery.

Besides HTTP, probes can check a TCP connection or run a command inside the container and inspect its result. The method changes, but the distinction between request readiness and the need for a restart remains. The next chapter follows how these observations lead to recovery from actual failures.

## Before Moving On

Here is what we covered. A Deployment declaration leads to Pod creation requests, Scheduler assignments, and container execution. The Kubelet reports status through the API so users can inspect progress with `kubectl`. Assessing whether a running Pod can receive requests also requires checking readiness. Probes provide the criteria for distinguishing startup completion, request readiness, and faults requiring a restart.

After detecting a problem, the next question is how to get the application working again. The next chapter follows Kubernetes recovery when an application stops or its host server fails. We will also investigate situations where execution keeps waiting or the same problem repeats instead of recovering automatically.

## References

- <a id="ref-1"></a>[1] [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)
- <a id="ref-2"></a>[2] [Pod Termination](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination)
- <a id="ref-3"></a>[3] [Pod Phase](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase)
- <a id="ref-4"></a>[4] [Configuring Startup, Readiness, and Liveness Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
