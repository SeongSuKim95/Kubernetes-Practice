<!--
  English publication based on 05-pod-failure-and-self-healing.draft.md.
  GitHub Flavored Markdown; figures use GitHub raw URLs.
-->

# Chap05. Pod Failures and Self-Healing: From Restarts to Troubleshooting

> This is the fifth chapter in a 16-chapter series. We explore how automatic recovery differs between Pod and Node failures, then examine graceful Pod termination and how to diagnose failures using status, events, and logs.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/01-k8s-logo.svg)

In Chapter 4, we saw how the Kubelet checks container execution and application responses, restarting containers when necessary. But what happens if the server running the application shuts down? Its Kubelet stops too, so the application needs a way to start again somewhere else.

Where a failure occurs determines which component handles recovery and what gets started again. A container might restart within the same Pod, or a new Pod might need to run on another Node. Understanding this distinction helps us recognize what Kubernetes is recovering during a failure.

The same error can recur after an application restarts. While Kubernetes retries, someone must investigate and fix the cause. Reading both the recovery progress and the conditions preventing execution helps us determine whether the application can serve requests again.

## 1. Pod Failures and Automatic Recovery

Continuing from Chapter 4, suppose a Deployment runs three web application Pods in the `default` Namespace. The Pod queries and deletion commands in this chapter also assume that the current Namespace is `default`. A failed web request can lead to different recovery paths depending on whether the problem affects a container or its Node.

- **Pod failure**: The Node is healthy, but an application container in the Pod has exited or stopped responding. The Kubelet on that Node handles container restarts based on termination status or liveness probe results.
- **Node failure**: The cluster cannot confirm that the Node hosting the Pod is healthy. If the failure persists, the Control Plane arranges for a replacement Pod to be created and assigned to another Node.

![Container restart and replacement Pod scheduling after Node failure across two Worker Nodes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/05/en/01-node-failure-recovery.gif)

Fig 1 distinguishes these failures with Pod A, Pod B, and Pod C running across two Worker Nodes. First, a container in Pod A fails. The Kubelet on Worker Node 1 detects its termination and asks the runtime to start it again. Pod A and its unique identifier, the **UID**, remain unchanged in the Control Plane; only the container process starts again.

If Worker Node 1 itself fails, responsibility shifts. Once heartbeats stop reaching the Control Plane and the failure persists, a controller begins removing the Pods associated with that Node. The ReplicaSet Controller asks the API Server to create Pod D to restore the Pod count. The Scheduler excludes Worker Node 1, which is `NotReady`, selects Worker Node 2 because it meets the requirements, and records the assignment in the API. The Kubelet on Worker Node 2 observes Pod D assigned to it and asks the runtime to start its containers. Pod D is a separate Pod from Pod A, so the application starts from the beginning. Although it runs on a different Node, the replacement created by the same ReplicaSet belongs to the same Namespace. Once Pod D passes its readiness checks, it can serve requests alongside Pod B and Pod C, which kept running on Worker Node 2. Pod names and restart counts also reveal which kind of recovery occurred.

### 1.1 Container Restarts Within the Same Pod

A Pod’s **restart policy** determines when a terminated container is started again. The Pods created by the Deployment in this chapter use `restartPolicy: Always`. While maintaining the Pod, the Kubelet restarts terminated containers regardless of why they exited. This policy also applies when a container is terminated following a failed liveness check, as discussed in Chapter 4. [[1]](#ref-1)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/interaction-container-restart.png" alt="A Node restarting a Container inside the same Pod" width="75%" />

The Node restarting the Container inside the Pod’s pouch represents the Kubelet asking the container runtime to restart it. Because the Pod stays in place while its container starts again, the following query checks both the Pod name and the container restart count.

```bash
kubectl get pod web-7c8d9f6b5d-a1b2c
```

```text
NAME                   READY   STATUS    RESTARTS      AGE
web-7c8d9f6b5d-a1b2c    1/1     Running   1 (20s ago)   8m
```

- `NAME`: The Pod keeps the same name as before the restart.
- `RESTARTS: 1`: The container has restarted once within the same Pod.
- `READY: 1/1`: The restarted container is ready to serve requests.

The new container must initialize and reconnect to external systems, so readiness may take time to recover. If only readiness checks fail, the container continues running while Kubernetes waits for recovery. Readiness and restart counts therefore need to be read together. Container restarts depend on the Node’s Kubelet and runtime being operational.

### 1.2 Replacement Pods After a Node Failure

When a Worker Node shuts down, its Kubelet can no longer restart containers. The Control Plane monitors Node status and periodic heartbeats. To distinguish temporary communication problems from persistent failures, it waits before declaring a failure and removing Pods. Nodes are cluster-scoped resources, so the following status query needs no Namespace selection.

```bash
kubectl get nodes
```

```text
NAME       STATUS     ROLES    AGE   VERSION
worker-1   NotReady   <none>   10d   v1.34.0
worker-2   Ready      <none>   10d   v1.34.0
```

- `NotReady` for `worker-1`: The Control Plane cannot confirm that this Node is healthy.
- `Ready` for `worker-2`: This Node may be a candidate for new Pods. It must also meet resource and other scheduling requirements.

If only communication is interrupted, container processes may still be running on the original Node. Read `NotReady` as the Control Plane being unable to confirm normal operation.

A persistent failure leads to the replacement process in Fig 1. Even if another Node is `Ready`, it must have sufficient resources for the new Pod. Otherwise, the Pod waits in `Pending`. Distributing Pods across Nodes and retaining spare capacity allows replacement Pods to start while the remaining Pods continue serving requests. [[2]](#ref-2)

To observe replacement without shutting down a Node, delete one Pod managed by a Deployment and watch the Pod count recover.

### 1.3 Pod Deletion and Replacement

As we saw in Chapter 4, a deletion request is recorded through the API Server, and the Kubelet on the assigned Node handles container termination. Meanwhile, the ReplicaSet Controller creates a new Pod to maintain the desired count. The following example deletes a Pod from a learning Deployment and then lists the Pods.

```bash
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

This example output assumes that the other two Pods are running normally.

- The old Pod ending in `a1b2c` has been deleted, and a new Pod ending in `k7m8n` has been created.
- `RESTARTS: 0` for the new Pod: Execution starts in a new Pod rather than restarting the old container.
- The new Pod still shows `ContainerCreating` and `0/1`, so it is not yet ready to handle requests.

The new Pod receives a different UID and may also receive a different IP address. It can serve requests after container startup, initialization, and readiness checks complete. Replacement is driven by the Pod count the Deployment maintains. A failed readiness check alone does not cause an extra Pod to be created while that Pod remains part of the managed set.

Preparation of the new Pod and termination of the old Pod can proceed concurrently. The termination process also needs to give the old application a chance to finish its in-flight work.

## 2. Graceful Pod Termination

Applications processing web requests or writing files need time to finish their work before exiting. Kubernetes provides that time during Pod deletion to support graceful termination.

![Concurrent termination of the old Pod and startup and readiness of its replacement](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/05/en/03-pod-termination.gif)

Fig 2 shows two flows originating from the same deletion request. Once the API Server records the request, the Kubelet running the old Pod observes its deletion state on the left. On the right, the ReplicaSet Controller requests a new Pod through the API to maintain the desired count.

The Kubelet on the original Node asks the container runtime to terminate the containers. The application typically receives `SIGTERM`, a request for graceful termination, and finishes its ongoing work. The application must implement this shutdown behavior in response to the signal. Network updates to exclude the terminating Pod from new request targets also proceed.

Meanwhile, on the right, the Scheduler chooses a Node for the new Pod and records the assignment in the API. The assigned Node’s Kubelet observes it and asks the runtime to start the containers, beginning application initialization. This can happen before the old Pod finishes terminating.

The time available for the old application to shut down is the **termination grace period**. The default for `terminationGracePeriodSeconds` is 30 seconds. In the first case in Fig 2, the application completes its work and exits within that period. Once the Kubelet reports termination, the old Pod is removed from the API, while the new Pod passes readiness checks and begins serving requests. [[3]](#ref-3)

In the second case, the new Pod becomes ready while the old application is still finishing its work. If the old process remains after the grace period expires, it is forcibly terminated. Graceful and forced termination thus lead to different outcomes, and termination and replacement can finish in either order. Fig 2 compresses time to compare the two cases.

After replacement, verify that the new Pod becomes ready and responds to real requests. If the new container exits again immediately or startup keeps stalling, investigate the cause rather than simply waiting for more retries.

## 3. Diagnosing Failures Through Status and Logs

If a container exits every time it starts because a required setting is missing, restarting it with the same configuration reproduces the error. While Kubernetes retries, the user needs to find and correct the missing setting.

Start by narrowing down where execution is blocked. Pod status and events identify the affected part of startup. If a container started and then exited, its logs can reveal application errors. The investigation differs depending on whether failure occurred after execution began or during preparation. The outputs below illustrate those differences.

### 3.1 Pod Status and Problem Identification

When requests fail, the Pod list helps distinguish Pods ready to serve requests from those needing investigation. Using the query from Chapter 4, we now examine readiness alongside restart counts. If production Pods are in `prod`, use `kubectl get pods -n prod -l app=web` and include `-n prod` in subsequent `describe` and `logs` commands. Follow the same Namespace from the initial list through details and logs.

```bash
kubectl get pods -l app=web
```

```text
NAME                   READY   STATUS             RESTARTS   AGE
web-7c8d9f6b5d-a1b2c    0/1     CrashLoopBackOff   4          4m
web-7c8d9f6b5d-d3e4f    1/1     Running            0          4m
web-7c8d9f6b5d-g5h6j    1/1     Running            0          4m
```

The other two Pods are ready, but the first Pod shows these signs of trouble:

- `CrashLoopBackOff` for the first Pod: The container has failed repeatedly and is waiting for its next restart.
- `RESTARTS: 4`: The container has restarted four times.
- `READY: 0/1`: No container in this Pod is currently ready to serve requests.

Repeated container exits trigger **backoff**, a delay between retries. Since the first Pod remains unready despite repeated restarts, we need to find out why its previous execution ended. [[1]](#ref-1)

### 3.2 Causes of Repeated Container Termination

Running `kubectl describe pod` on the first Pod shows both its current waiting state and the previous container termination record.

```bash
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

Container status and events connect the previous termination to the current state.

- `State: Waiting` and `Reason: CrashLoopBackOff`: The container is currently waiting for its next restart.
- `Last State: Terminated` and `Exit Code: 1`: The previous execution ended with an error.
- The `BackOff` event: A restart delay is being applied after repeated failures.

The previous execution failed with exit code 1, so we turn to its application logs for a specific cause. `--previous` requests logs from the previously terminated container, and `-c web` selects the container. [[4]](#ref-4)

```bash
kubectl logs web-7c8d9f6b5d-a1b2c -c web --previous
```

```text
ERROR: required environment variable DATABASE_HOST is missing
```

The log reports that the required environment variable `DATABASE_HOST` is missing. Update the Deployment’s Pod template to supply this value, then check whether the new Pod becomes ready. Moving from the termination record to the logs connects the recurring failure to the configuration that needs correction.

### 3.3 Pod Scheduling Failure Due to Insufficient Memory

A Pod without an assigned Node is blocked before application logs exist. If a Pod stays `Pending`, first check whether it has been assigned to a Node.

Consider a separate situation in which the container in a new Pod requests 4 GiB of memory. All other scheduling conditions are met, but Worker Node 1 has only 1 GiB left for new Pods, and Worker Node 2 has 2 GiB.

The new Pod needs all 4 GiB on one Node. Neither Node can meet that request, so the Pod waits for assignment. “Remaining memory” in the figure means capacity available for new Pod requests after accounting for system reservations and existing Pod requests, rather than instantaneous memory usage.

![Kubelets reporting Node status to the API Server and the Scheduler recording failure after comparing remaining memory](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/05/en/02-pod-pending.gif)

In Fig 3, each Node’s Kubelet reports its resources and status to the API Server. The Scheduler reads Node information and Pod specifications through the API Server and calculates remaining memory after accounting for existing Pod requests. Reporting and scheduling repeat independently; the Scheduler does not need to wait for both reports in the sequence shown.

If the Scheduler finds no suitable Node, it records the scheduling failure through the API. In this example, no Node is assigned, so no Kubelet starts the containers and the Pod remains `Pending`.

A `kubectl get pod` query shows both the waiting state and whether a Node has been assigned.

```bash
kubectl get pod web-7c8d9f6b5d-g5h6j -o wide
```

```text
NAME                   READY   STATUS    RESTARTS   AGE   IP       NODE
web-7c8d9f6b5d-g5h6j    0/1     Pending   0          2m    <none>   <none>
```

- `STATUS: Pending`: Preparation for container execution is not complete.
- `NODE: <none>`: The Scheduler has not assigned a Node to run this Pod.

Inspecting the details reveals what prevented scheduling.

```bash
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

The resource request and event message explain the scheduling failure.

- `Requests.memory: 4Gi`: The container requests 4 GiB of memory.
- `2 Insufficient memory` in the `FailedScheduling` event: Neither Node has enough memory available for the request.

To resolve this, review the application’s memory needs and correct an excessive request, or provide a Node with sufficient capacity. Deleting and recreating the Pod with the same request will reproduce the scheduling failure. [[5]](#ref-5)

Even after Node assignment, an image name typo or registry access failure can prevent container startup. The Pod phase remains `Pending`, while `STATUS` in `kubectl get pods` may show `ErrImagePull` or `ImagePullBackOff`. Check the image download failure in `kubectl describe pod` events and correct the image name or access configuration. The causes to investigate therefore differ before and after Node assignment. [[6]](#ref-6)

## Before the Next Chapter

Here is what we covered. On a healthy Node, the Kubelet restarts containers within the same Pod. If a Node failure persists, controllers create a replacement Pod and the Scheduler selects another Node. When a Pod is deleted, the termination grace period gives the application time to finish its work. If automatic recovery keeps repeating without resolving the cause, use status, events, and previous container logs together to identify what needs fixing.

Recovery can create a new Pod with a different address. Communication becomes difficult if other applications must discover every address change. In the next chapter, we will explore how a Service lets applications receive requests through the same name and address even when Pods are replaced.

## References

- <a id="ref-1"></a>[1] [Kubernetes documentation: Container restart policies and repeated failures](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-restarts)
- <a id="ref-2"></a>[2] [Kubernetes documentation: Node failure handling](https://kubernetes.io/docs/concepts/architecture/nodes/#node-controller)
- <a id="ref-3"></a>[3] [Kubernetes documentation: Pod termination](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination)
- <a id="ref-4"></a>[4] [Kubernetes documentation: kubectl logs](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/)
- <a id="ref-5"></a>[5] [Kubernetes documentation: Resource requests and Node scheduling](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- <a id="ref-6"></a>[6] [Kubernetes documentation: Troubleshooting Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
