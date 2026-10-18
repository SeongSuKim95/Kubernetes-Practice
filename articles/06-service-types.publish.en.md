<!--
  English publication based on 06-service-types.draft.md.
  GitHub Flavored Markdown; figures use GitHub raw URLs.
-->

# Chap06. Services and Cluster Communication

> This is the sixth chapter in a 16-part series. We begin with how Pods communicate and why Services are needed. After following a Service name to an IP address and a request to its destination Pod, we compare the access methods provided by the four Service types.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/01-k8s-logo.svg)

Chapter 5 explored how Kubernetes restarts containers or replaces Pods after a failure. When a replacement Pod receives a different IP address, applications sending requests to the old address need a new destination. Restoring execution must therefore be accompanied by a way for requests to reach the new Pod.

Imagine an online store whose web application and product API run in separate Pods. The web application requests product lists from the API. If it has to update its list of destination addresses whenever API Pods are replaced or added, it becomes harder to benefit fully from automated recovery and deployment.

What if clients could keep using the same name and address while the Pods receiving requests changed behind them? A Service provides this kind of access point. Whether applications communicate inside the cluster, receive requests from external users, or call external systems, the access method can be chosen to suit the sender and receiver.

## 1. Communication Between Pods and the Need for Services

To understand the access point a Service provides, let us start with two Pods communicating directly through their addresses.

### 1.1 Communication Within the Cluster Using Pod IPs

Chapter 3 explained that containers in the same Pod share a network and can communicate through `localhost`. Separate Pods have their own IP addresses, so calling an application in another Pod requires that Pod's IP and the port on which the application listens. A **client** is the application sending a request; a Pod inside the cluster can also be a client.

For example, when a web Pod sends an HTTP request to a product API Pod at `10.244.2.8:80`, the API process listening on port 80 at that address receives the request and responds. Applications in separate Pods exchange data using familiar HTTP requests and responses.

The cluster's network plugin connects Pods so they can communicate by IP even when they run on different Nodes. The web Pod and API Pod can therefore communicate this way regardless of their placement. Namespaces separate resource management scopes; restricting communication between Pods requires a separate network policy. [[1]](#ref-1)

### 1.2 Pod Replacement and the Limits of Address Management

Knowing a Pod's IP enables direct communication, but that address may not remain usable. If the product API Pod at `10.244.2.8` is replaced by a new Pod assigned `10.244.1.9`, the old address stored in the web application no longer points to the same destination.

Scaling the API to two Pods adds another problem. The web application must choose an address and update its list whenever Pods disappear or are added. While the Deployment maintains the Pod count, the caller still needs to know which Pod addresses can receive requests.

What we need is **an access point that continues to reach applications serving the same role**, instead of remembering a particular Pod's address. [[2]](#ref-2)

### 1.3 Service as an Application Access Point

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/svc.svg" alt="Official Kubernetes Service icon" width="260">

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-service.png" alt="Service providing a stable access point for changing Pods" width="70%" />

A **Service** is a Kubernetes networking resource that declares how to access an application. In the most common configuration, it gives a group of Pods serving the same role a single name and virtual IP, with connections to that access point forwarded to a Pod able to handle requests. The client remembers the Service name rather than the location of each Pod. [[3]](#ref-3)

The information desk in the illustration represents the Service access point that clients visit, while the Pods behind it represent the destinations that handle requests. Even when those Pods are replaced, clients return to the same desk.

A **virtual IP** identifies the Service access point rather than the location of a particular Pod. The cluster associates this address with actual Pod addresses using declarations recorded in the API. The application inside a Pod receives requests and responds; the Service itself does not run a server process.

A Deployment manages **which Pods to run and how many**, while a Service defines **the name and port used to access that group of Pods**. Before clients can send requests using a Service name, we need to specify which Pods belong behind that access point.

## 2. Service Declarations and Target Pods

Let us connect two web server Pods to a single Service access point. Fig 1 shows how the declaration that maintains Pods relates to the declaration that selects request destinations.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/08-service-pod-relationship.svg" alt="Deployment-managed web Pods, Service selection, and client access" width="100%" />

### 2.1 The Relationship Between an Application and Its Access Point

The blue area at the upper left of Fig 1 is Worker Node A, where the client Pod runs. The client accesses the web application using the name `web` from the Service on the right. The green areas below are Worker Nodes B and C, each containing a web Pod that handles requests.

The gray dashed lines from the Deployment at the upper right show the management relationship that creates and maintains the web Pods. Its Pod template carries the Label `app=web`, so newly created Pods receive the same marker. The purple dashed lines from the Service show how this Label selects request destinations. Client requests reach a selected web Pod through the Service access point; the Deployment is outside the request forwarding path.

A Service looks for matching Pod Labels within its own Namespace. For example, a Service in `dev` selects web Pods in `dev`; Pods in `prod` are outside its selection even if they have the same Label.

Adding a name for clients and ports for requests to this selection relationship completes the basic Service configuration.

### 2.2 Service Names, Targets, and Ports

For the web application in Fig 1, the Service declaration needs the following information.

- **Access name**: The name clients use to find the application, here `web`.
- **Pod selection criteria**: The conditions that identify Pods serving the same role. The Service's Selector matches Labels attached to Pods.
- **Ports**: The mapping between the Service port used by clients and the Pod-side port where the application receives requests.

The Service port and the application's listening port can differ. The web server examples that follow use port 80 for both.

This approach also works for applications such as databases. A Service forwards connections based on IP addresses, ports, and protocols such as TCP. TCP is a communication protocol used to exchange web requests or database commands, and it is the default protocol for a Service. [[3]](#ref-3)

### 2.3 Labels and Selectors in Manifests

Let us translate the selection relationship in Fig 1 into manifests, using the illustration below.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/interaction-service-deployment-labels-selected.png" alt="Deployment managing matching web Pods and Service selecting client request targets" width="85%" />

The Deployment on the right manages two web Pods with matching light-blue markers. The markers on the Pods represent the Label `app: web`; the matching marker held by the Service represents the Selector that looks for that Label.

The Pod holding an envelope on the left is a client sending a request to the Service's name and port. The envelope and colored band represent the request to the web application and its destination.

First, declare the Deployment as follows. It maintains two web Pods in the `default` Namespace and sets the Label `app: web` in the Pod template.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.28
        ports:
        - containerPort: 80
```

- `replicas` and `template`: Define the Pod count to maintain and the common configuration for new Pods.
- `template.metadata.labels`: Adds a Label identifying each created Pod as part of the web application. The Deployment's `selector.matchLabels` matches this Label as well.

In these Pods, the nginx web server receives requests on port 80. Next, declare a Service in the same `default` Namespace. Its Selector uses `app: web` to select those Pods and makes them accessible through the name `web` and port 80.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: default
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

- `metadata.name`: The name clients look up.
- `spec.selector`: The conditions for selecting candidate destination Pods, matching the Label in the Pod template above.
- `port` and `targetPort`: Map the Service's access port to the application's actual port.

The declarations have different names: `web-app` and `web`. **The relationship is established by Pod Labels and the Service Selector, rather than resource names.** Replacement Pods with the same Label remain candidates for the same Service.

With the target Pods linked to an access name, we can now follow how a client uses that name to find the address it will contact.

## 3. Service Address Lookup and Request Forwarding

When this Service is created, Kubernetes automatically assigns a virtual IP for use inside the cluster. Here, assume that the `web` Service receives `10.96.10.20`. [[3]](#ref-3)

Accessing `http://web:80/` involves two activities: finding the IP address for `web`, and sending a web request to that address.

### 3.1 Service Address Lookup Through CoreDNS

**DNS** (Domain Name System) tells a client which IP address corresponds to a name. Finding an address from a name is called **name resolution**. [[4]](#ref-4) In Kubernetes, a DNS server program called **CoreDNS** usually answers this question. Like a web server, CoreDNS runs in a container inside a Pod and helps other applications find the addresses associated with Service names. [[5]](#ref-5)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/06-service-dns-resolution.svg" alt="CoreDNS, API Server information, and Service IP lookup" width="100%" />

Worker Node B in Fig 2 contains a CoreDNS Pod. CoreDNS first obtains the `web` Service's name and IP information through the API Server, then reflects subsequent Service creations and changes. [[6]](#ref-6) When the client on Worker Node A asks for the address of `web`, CoreDNS looks up `10.96.10.20` in the information it holds and returns it. The client can use that address as the destination for a web request.

The `coredns` Deployment at the top maintains the DNS server Pods. For example, `kubeadm` installs CoreDNS by default when creating a cluster, so it may already be running before you deploy a web server. The cluster configuration determines the number and placement of CoreDNS Pods. [[5]](#ref-5)

Service name lookups also follow the Namespace boundaries introduced in Chapter 3. A client in the same Namespace as the Service can use the short name `web`. A Pod in `dev` looking for a Service in `prod` includes the Namespace, as in `web.prod`. With the cluster domain `cluster.local`, the full name is `web.prod.svc.cluster.local`. [[4]](#ref-4)

The following command shows the DNS server Pods actually running in the cluster. `kube-system` is the Namespace for Kubernetes system components.

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns \
  -o custom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName
```

Here is example output showing two CoreDNS Pods.

```text
NAME                       IP            NODE
coredns-76f75df574-abcde     10.244.2.3    worker-b
coredns-76f75df574-fghij     10.244.3.4    worker-c
```

- `IP`: The address of the CoreDNS Pod itself, where the DNS server runs.
- `NODE`: The Node to which that Pod is assigned.

A CoreDNS Pod's IP can also change upon replacement, so clients send queries to the stable address of the DNS Service, `kube-dns`. Ordinary Pods are configured to use this address as their DNS server. The lookup in Fig 2 therefore reaches CoreDNS through this Service in practice. DNS queries use Service forwarding too. [[5]](#ref-5)

### 3.2 Forwarding Paths for DNS Queries and Web Requests

The client uses two access points: `kube-dns` for DNS queries and `web` for web requests. Both Services use virtual IPs, so the Node needs rules specifying **which Pod should receive requests sent to each address**.

**kube-proxy**, a process running on each Node, prepares these rules. It obtains Service and target information from the API Server and configures forwarding rules in the Node's operating system. The operating system applies those rules when requests arrive. This explanation uses a configuration with kube-proxy. [[7]](#ref-7)

Target information is recorded in an API resource called an **EndpointSlice**, which contains the addresses, ports, and readiness of Pods associated with a Service. The Service selects Pods by Label, and EndpointSlices represent the results as the address information needed to reach them. Think of this as **a mapping table between a Service and its target Pods**. [[8]](#ref-8)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/09-coredns-stable-entry.gif" alt="DNS lookup and requests through a virtual IP to a Pod" width="100%" />

At the top of Fig 3 are two kinds of information: the left table shows **Service names and virtual IPs**, and the right table shows **target Pod addresses and ports recorded in EndpointSlices**. CoreDNS uses the left-hand information to answer with a Service IP. kube-proxy combines both to prepare the Node's forwarding rules. This preparation and synchronization happen independently of the client's web requests.

Once CoreDNS has the address for `web` and Node A has its forwarding rules, the client begins the lookup. It asks for `web` at its configured DNS server address, `10.96.0.10`, the IP of the `kube-dns` Service. Node A's DNS forwarding rule sends this query to the CoreDNS Pod at `10.244.2.3:53` on Worker Node B. Port 53 is where the DNS server receives queries.

CoreDNS returns `10.96.10.20`, the Service IP for `web`. The client then sends a web request to port 80 at that address. This time, Node A's web forwarding rule changes the destination to `10.244.3.8:80`, the web Pod on Worker Node C. The web application running there handles the request.

The purple path discovers the address, and the blue path uses it to call the application. Once the address is known, web requests can reach the target Pod using the Service IP and the Node's forwarding rules without going through CoreDNS again.

### 3.3 Request Distribution Across Multiple Pods

So far, we have followed a request to one web Pod. When two ready web Pods belong to the same Service, the request path depends on which Pod the Node's forwarding rules select.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/07-service-packet-path.svg" alt="Requests to one Service IP reaching replicas on different Nodes" width="100%" />

In Fig 4, a Deployment maintains one web Pod on Worker Node B and another on Worker Node C. Both have the Label `app=web` and are ready to receive requests, so both appear in the target list for the `web` Service. Node A's kube-proxy configures forwarding rules using this list.

The client sends both request 1 and request 2 to `10.96.10.20:80`. The figure shows separate new connections for the requests, with a different Pod selected for each. Node A's rules change request 1's destination to `10.244.2.8:80`, where Node B's web Pod handles it. Request 2 goes to `10.244.3.8:80`, where Node C's web Pod handles it.

To distribute requests as in Fig 4, eligible Pods are identified first, and one is then selected. The basic criteria and settings that affect this choice are as follows.

- **Labels and readiness**: In this example, candidates match the Service's Selector and are ready to receive requests. [[3]](#ref-3)
- **Selection for a new connection**: With kube-proxy's `iptables` or `nftables` mode, a candidate is selected randomly by default. Requests 1 and 2 could therefore reach different Pods or the same Pod. [[7]](#ref-7)
- **Affinity by client IP**: Setting `sessionAffinity: ClientIP` on a Service can direct connections from the same client IP to the same Pod. The default is `None`, which the earlier manifest also uses. [[7]](#ref-7)

A Pod is selected when a new connection is established. Multiple web requests sent over an existing connection go to the same Pod. Since distribution uses the current candidate set, the targets in the forwarding rules must also change when Pods are added or replaced.

### 3.4 Target Updates After Pod Replacement and Readiness Changes

The **EndpointSlice Controller** manages this target list by watching Service and Pod changes in the Control Plane. It finds Pods matching the Selector in the Service's Namespace and records their addresses and readiness in EndpointSlices. Fig 5 follows how this information reaches the forwarding rules when a Pod is replaced. [[8]](#ref-8)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/10-service-target-update.gif" alt="Target information and Node forwarding rules updated after Pod replacement" width="100%" />

In Fig 5, the existing web Pod at `10.244.3.8` handles requests and then terminates. A new web Pod receives `10.244.3.9` and becomes ready. Once the EndpointSlice Controller updates the target information with the new address, kube-proxy receives the change and updates Node A's forwarding rules to use the new Pod IP.

Throughout this process, CoreDNS keeps the Service IP for `web` as `10.96.10.20`. A later name lookup in the figure returns the same address. A client that already knows it can continue sending new requests; the updated Node rules forward them to `10.244.3.9`. Pod replacement changes the destination behind the access point, while the client's access address stays the same.

Readiness matters alongside Labels. In practice, a new Pod's address may appear in an EndpointSlice before the Pod is ready, and kube-proxy considers readiness when determining forwarding targets. If the readiness check from Chapter 4 fails, the Pod is excluded from new connections through an ordinary Service; it can be included again when readiness recovers. [[9]](#ref-9)

Resolving a Service name and receiving an application response are separate steps. A regular ClusterIP Service can still resolve to its Service IP even when no Pods are ready. For a request sent to that address to be processed, there must be a ready Pod and a working forwarding path to it. When troubleshooting access, first check whether the name resolves to an address, then check whether a request to that address receives an application response. Requests may also fail while Pod replacement information is being propagated, requiring the client to reconnect.

This internal communication model can also support requests from external users or access to external systems. Kubernetes provides four values for `spec.type` to choose the access method: **ClusterIP, NodePort, LoadBalancer, and ExternalName**.

## 4. Service Types for Internal and External Communication

The appropriate type depends on where the sender and receiver are located.

- **ClusterIP**: Communication between applications in the same cluster using a Service name and virtual IP.
- **NodePort**: External clients connecting through a reachable Node IP and a designated port.
- **LoadBalancer**: Requests arriving through an external load balancer's address and forwarded to an application in the cluster.
- **ExternalName**: Internal applications using a Service name as an alias for an external system's DNS name.

We will compare ClusterIP, NodePort, and LoadBalancer using the same web Pods. For ExternalName, we will look at internal Pods calling an external API.

### 4.1 ClusterIP: Communication Between Internal Pods

Imagine an order-processing Pod asking a product lookup Pod in the same cluster for inventory information. If product lookup is used only internally, an access point that the order application can call by Service name is sufficient. **ClusterIP** serves this purpose.

The `web` Service from Section 2 and the request path in Section 3 already use this approach. Omitting `spec.type` selects ClusterIP, so the earlier declaration has already created an internal access point. [[3]](#ref-3)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/03-clusterip-traffic.gif" alt="ClusterIP request and response through a selected Pod" width="100%" />

Fig 6 shows a request for which the lower of the two web Pods is selected. The client on Node A sends a request to the Service IP for `web`, and the Node's rules forward it to a web Pod on Node B. The result returns to the client. Internal applications communicate this way using the Service's name and port.

A typical computer outside the cluster has no route to this virtual IP. Access from a developer's PC or an external user requires an additional address and port reachable from outside.

### 4.2 NodePort: External Access Through a Node Port

**NodePort** retains the internal ClusterIP access point and adds an entry point at a designated port on Nodes. Clients send requests to a reachable `Node IP:nodePort`.

For example, a developer can use this to check a web page from a PC against an internal test cluster without an external load balancer. If the PC can reach a Node, a request to `Node IP:30080` can verify the application. A separately managed load balancer can also forward to this port on each Node. [[3]](#ref-3)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/02-nodeport-paths.svg" alt="Internal Service access and external NodePort access" width="100%" />

The blue path in Fig 7 is the existing internal path. When the client on Node A requests the Service IP, Node A's rules select and forward to a destination Pod. On the orange path, an external client connects to **Node B's IP on port 30080**. Node B applies the Service forwarding rules to the incoming request and sends it to a web Pod.

Both requests in the figure reach web Pod 1 on Node B. Web Pod 2 on Node C is also a candidate for the same Service and can be selected for another request. The internal access point and the Node port entry point lead to the same set of Pods.

The following declaration applies this access method to the web application.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: default
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
    nodePort: 30080
```

- `spec.type: NodePort`: Adds a Node port entry point alongside internal access.
- `nodePort: 30080`: The port external clients use at `Node IP:30080`. Internal clients continue to use the Service's `port: 80`; both paths lead to the web server at `targetPort: 80`.

If `nodePort` is omitted, a port is automatically allocated from the default range 30000–32767. This range can vary with cluster configuration. External access also requires a network path to the Node and a firewall or cloud security group allowing the port.

### 4.3 LoadBalancer: Access Through an External Load Balancer

Giving customers a particular Node address with NodePort means they need another address if that Node fails. An external load balancer provides one access address and selects a destination behind it. **LoadBalancer** is the Service type that requests this external access point. [[3]](#ref-3)

A **controller** connecting the cluster to its external environment turns the declaration into a working load balancer. Available load balancers depend on the implementation installed or provided in that environment. In a cloud, a controller creates and configures the provider's load balancer; on your own servers, a separate implementation supplies external access. It is therefore necessary to know which implementation handles the common `type: LoadBalancer` declaration.

Here, we will use **AWS Load Balancer Controller** to create an AWS **NLB** (Network Load Balancer). Running inside the cluster, the controller reads Service declarations through the Kubernetes API and creates and manages the NLB and forwarding configuration through the AWS API. The controller must be installed and have IAM permissions to manage the AWS resources. With this setup, a Service declaration requests creation without requiring the user to create an NLB in the AWS console first. [[10]](#ref-10)

This declaration requests an internet-facing NLB and selects `instance` mode, which uses Nodes as its forwarding targets.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  loadBalancerClass: service.k8s.aws/nlb
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
```

- `spec.type: LoadBalancer` and `spec.loadBalancerClass`: Request external access and assign its handling to AWS Load Balancer Controller.
- `aws-load-balancer-nlb-target-type: instance`: Directs the NLB to forward requests to each target Node's NodePort.
- `aws-load-balancer-scheme: internet-facing`: Requests an internet-facing NLB.

Although this declaration omits `nodePort`, Kubernetes allocates an available NodePort by default when creating a `LoadBalancer` Service. The allocated value is recorded in the Service's `spec.ports[].nodePort` through the API Server. Fig 8 assumes that `30080` was allocated. [[3]](#ref-3)

AWS Load Balancer Controller reads this value, calls the AWS API to create the NLB, and registers the destination Nodes with port `30080`. AWS groups these destinations and ports in a resource called a **Target Group**. The controller then creates a **listener**, the NLB's configuration for receiving traffic, on port 80 and connects it to those registered targets. The controller writes the target and port configuration that a user would otherwise enter in the AWS console. [[10]](#ref-10)

The NLB now has a listening port and forwarding targets. Fig 8 follows actual requests through this configuration.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/04-loadbalancer-aws-topology.svg" alt="AWS NLB forwarding to two Worker Nodes and web Pods" width="100%" />

Worker Nodes B and C sit side by side behind the NLB in Fig 8, both registered as forwarding targets. When an external client requests the NLB on port 80, the NLB selects a target for the new connection and forwards it to port 30080 on that Node. The left path reaches web Pod 1 through Node B; the right path shows a request on another connection reaching web Pod 2 through Node C.

After the NLB chooses a Node, that Node's Service forwarding rules select the final Pod. The figure shows paths to Pods on the receiving Nodes, while the default configuration also allows forwarding to ready Pods on other Nodes. Clients use the same NLB address without choosing these targets themselves.

Each port in this path has a different role and configuration owner.

- **NLB listening port `80`**: AWS Load Balancer Controller reads the Service's `port: 80` and configures the listener. The internal Service port uses the same value.
- **Node listening port `30080`**: Kubernetes automatically allocates this NodePort. The controller uses it as the NLB's forwarding port.
- **Web Pod listening port `80`**: The web server listens here, as specified by the Service's `targetPort: 80`. The Node's forwarding rules send requests to this port.

The controller thus configures the forwarding port as well. If you create the NLB directly through the AWS console or Terraform, you must configure its forwarding port to match the actual NodePort.

In `ip` mode, unlike Fig 8, the NLB registers Pod IPs as targets and can forward directly to Pods. [[10]](#ref-10) Implementations that bypass NodePort this way can also be configured to disable automatic NodePort allocation. [[11]](#ref-11)

So far, requests have entered the cluster's web Pods. In the opposite direction, applications inside the cluster may need a way to manage the names they use to call external systems.

### 4.4 ExternalName: A DNS Alias for an External System

Suppose an internal application retrieves information from `api.example.com` outside the cluster. Mapping the internal name `api` to that external name lets a Service manage the alias the application uses. **ExternalName** is the type that associates a Service name with an external DNS name. [[12]](#ref-12)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/05-externalname-traffic.gif" alt="ExternalName DNS alias lookup and external API request" width="100%" />

The Deployment in Fig 9 maintains two client Pods that call an external API. Unlike the web Pods receiving requests in earlier figures, these Pods are the senders.

When the client Pod on Node A looks up `api` in Fig 9, CoreDNS returns the external name `api.example.com` as a **CNAME**. A CNAME is an alias response pointing to another DNS name. Resolution continues by following that alias to find the external name's IP address. Purple arrows show queries and responses; the example assumes the external name resolves to `203.0.113.10`.

After the address is found, the path turns orange. The client Pod sends a web request to port 80 at `203.0.113.10`, and the external API server receives it directly. CoreDNS helps find the address, while the API request travels from the client to the external server. The client Pod on Node B can use the same name and process.

The figure separates alias discovery from IP lookup. An actual DNS response may include both the alias and the IP address, or resolution may use a cached address.

This declaration makes the external API discoverable through the internal name `api`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: default
spec:
  type: ExternalName
  externalName: api.example.com
```

- `metadata.name: api`: The internal Service name clients look up.
- `spec.type: ExternalName` and `spec.externalName`: Associate the Service name with the external DNS name `api.example.com`.

After establishing the name mapping, check both the network path to the external server and the names used by HTTP or HTTPS. Requests can fail if the alias `api` differs from the host name or certificate name expected by the external server, so the server and client configurations must agree.

Just as the client discovered an external server's address and connected directly, an internal application may need to discover individual Pod addresses and connect without a virtual IP.

### 4.5 Headless Service: Pod Addresses Without a Virtual IP

Interchangeable web server Pods can handle a request regardless of which one receives it. A group of database Pods that needs data from a particular member, however, must distinguish that member's address. A **Headless Service** supplies target Pod addresses through DNS instead of a virtual IP. It uses `spec.type: ClusterIP` with `spec.clusterIP: None`, so it is a configuration of ClusterIP within the four types above. [[3]](#ref-3)

When the StatefulSet introduced in Chapter 3 is linked to a Headless Service, a specific Pod can be found using `<pod-name>.<service-name>` in the same Namespace. If replacement changes the Pod IP, clients can look up the same name again and reconnect to the new address. [[13]](#ref-13)

This configuration also suits applications that receive multiple server addresses and choose a destination by their own criteria. A Headless Service provides the ready Pod addresses, and the application or communication library selects one. We will use the same two web Pods to follow this lookup and selection process. [[3]](#ref-3)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-headless
  namespace: default
spec:
  type: ClusterIP
  clusterIP: None
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

- `spec.clusterIP: None`: Disables allocation of a Service virtual IP and makes target Pod addresses available through DNS.

Fig 10 shows the addresses returned by a lookup with this declaration. Both web Pods are assumed to be ready for requests.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/11-headless-service-traffic.gif" alt="Headless lookup returning two Pod IPs followed by client selection and a direct request" width="100%" />

When the client Pod in Fig 10 looks up `web-headless`, CoreDNS returns the two web Pod IPs, `10.244.2.8` and `10.244.3.8`. The client receives the addresses of the actual destinations rather than a Service virtual IP.

The client application or its communication library then chooses an address. In the figure, it selects `10.244.2.8` and follows the blue path to port 80 on web Pod 1 in Worker Node B. Because it starts with a Pod IP, the request reaches that Pod without translating a Service virtual IP to a Pod IP. [[3]](#ref-3)

Even with the same web Pods, the address returned to the client and the component selecting a destination differ between these configurations.

- **Ordinary ClusterIP configuration**: DNS returns the shared Service virtual IP, and the Node's forwarding rules choose a target Pod.
- **Headless configuration**: DNS returns ready Pod IPs, and the client application or communication library chooses a target.

A concrete database example is a MySQL primary and replica configuration. The Kubernetes documentation combines a Headless Service for finding the primary by its individual name with a normal ClusterIP Service for distributing read requests. Fig 11 simplifies this relationship to two Pods. [[14]](#ref-14)

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/06/en/12-mysql-headless-example.png" alt="Writing and replication through the primary's individual name, compared with reads through a normal Service" width="100%" />

Consider saving an order in an online store. The **primary** on the left records changes, and the **replica** on the right receives and stores those changes. They maintain the same data but have different roles, so the destination of a connection matters.

- **Saving an order:** The application uses the primary's individual name to find that Pod and send a write request. This uses the per-Pod name provided by the Headless Service and StatefulSet.
- **Replicating data:** The replica resolves the same primary-specific name to establish a replication connection. The orange arrow shows the direction in which the replica connects; changes travel from the primary to the replica over that connection.
- **Browsing products:** Read requests that can tolerate replication lag use the normal Service's shared read address. In the official example, any ready primary or replica Pod can be selected; the diagram shows the replica being selected.

If replication connections were distributed to arbitrary Pods, a replica could connect to itself. A Headless Service allows the specific primary to be addressed, while a normal Service is suitable when any server ready to handle reads can be used. The application chooses an address according to its purpose, and the configured MySQL replication mechanism copies the data.

## Before Moving On

Here is what we covered in this chapter. Pods running an application can be replaced, but communication becomes difficult if callers must find a new address each time. A Service separates the address used to access an application from the Pods that actually handle requests, so callers can keep using the same access point as Pods change. Kubernetes tracks destination addresses and readiness so requests can reach Pods that are able to handle them.

When choosing an access method, start with who will send requests and from where. Consider whether reaching any one of several Pods is sufficient or whether the caller needs to connect to a specific Pod. The approaches compared in this chapter provide ways to reach applications according to those needs.

With a way to reach each application in place, we can now consider how to offer several features through a single website. The next chapter explores how to direct requests arriving at one entry point to the appropriate application and protect communication between users and the site.

## References

- <a id="ref-1"></a>[1] [Kubernetes network model](https://kubernetes.io/docs/concepts/services-networking/)
- <a id="ref-2"></a>[2] [Provided Kubernetes textbook, Chapter 3: Sections 3.1 and 3.5, printed pages 80–84 and 103–107](../Textbook/%E1%84%80%E1%85%B5%E1%86%B7%E1%84%89%E1%85%A5%E1%86%BC%E1%84%89%E1%85%AE_%E1%84%8F%E1%85%AE%E1%84%87%E1%85%A5%E1%84%82%E1%85%A6%E1%84%90%E1%85%B5%E1%84%89%E1%85%B3%20%E1%84%80%E1%85%AD%E1%84%80%E1%85%AA%E1%84%89%E1%85%A5_ocr_3%E1%84%8C%E1%85%A1%E1%86%BC.pdf)
- <a id="ref-3"></a>[3] [Service concepts and types](https://kubernetes.io/docs/concepts/services-networking/service/)
- <a id="ref-4"></a>[4] [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- <a id="ref-5"></a>[5] [Using CoreDNS in Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/coredns/)
- <a id="ref-6"></a>[6] [CoreDNS Kubernetes plugin](https://coredns.io/plugins/kubernetes/)
- <a id="ref-7"></a>[7] [Virtual IPs and Service proxies](https://kubernetes.io/docs/reference/networking/virtual-ips/)
- <a id="ref-8"></a>[8] [EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)
- <a id="ref-9"></a>[9] [Liveness, readiness, and startup probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- <a id="ref-10"></a>[10] [AWS Load Balancer Controller: NLB](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/nlb/)
- <a id="ref-11"></a>[11] [NodePort allocation for LoadBalancer Services](https://kubernetes.io/docs/concepts/services-networking/service/#load-balancer-nodeport-allocation)
- <a id="ref-12"></a>[12] [ExternalName Services](https://kubernetes.io/docs/concepts/services-networking/service/#externalname)
- <a id="ref-13"></a>[13] [StatefulSet stable network identity](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#stable-network-id)
- <a id="ref-14"></a>[14] [Kubernetes: Run a Replicated Stateful Application](https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/)
