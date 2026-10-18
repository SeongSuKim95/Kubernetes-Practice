<!--
  English publication based on 07-ingress-and-https.draft.md.
  GitHub Flavored Markdown; figures use GitHub raw URLs.
-->

# Chap07. Ingress and HTTPS: Connecting External Requests to Services

> This is the seventh chapter in a 16-part series. Building on the Service types compared in Chapter 6, we explore how Ingress connects external HTTP and HTTPS requests to Services.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/01-k8s-logo.svg)

When browsing products and placing orders in an online store, users feel they are using a single site. Behind the scenes, however, the application that displays pages may run separately from the applications that retrieve product information or process orders. Splitting these responsibilities should not require users to switch addresses every time they use a different feature.

The previous chapter established stable ways to reach applications. To bring those access points together as one site, we now need an entry point that reads incoming requests and directs them to the right application. A request for a product list should reach the application responsible for product information, while an order should reach the application that processes orders.

Sensitive information, including login details and delivery addresses, also passes through this entry point. Along with sending requests to the right destination, we need to protect communication between the user and the site. Let us explore how Ingress and HTTPS meet these needs.

## 1. External HTTP Requests and the Role of Ingress

Once an external request reaches the cluster, something must decide which application should receive it. We will begin with how the contents of an HTTP request determine the destination Service.

### 1.1 HTTP Routing Rules Beyond Service Access

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/ing.svg" alt="Official Kubernetes Ingress resource icon" width="260">

In Chapter 6, a request sent to a Service was handled by one of its ready Pods. If the Pods serving web pages and the Pods returning product information are separate, we can group them behind the `web` and `api` Services. We now need a way to determine which group should receive each external request.

Each Service could be exposed as a `LoadBalancer`, but users expect to open pages and browse products within the same site. A more natural arrangement is to receive requests at one public address and choose their destinations by the requested name and path.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-ingress.png" alt="Ingress directing external HTTP requests to Services by request conditions" width="70%" />

Consider browsing a product catalog in an online store. Although the user visits a single site, the application serving pages to the browser and the application retrieving product names and prices can run separately. Requests for pages should go to the page-serving Service, while requests for product data should go to the product lookup Service.

**Ingress** is an API resource that declares which Service should receive an external HTTP or HTTPS request. It distinguishes destinations using the **host**, the name of the requested site, and the **URL path**, the requested location within that site. Users can therefore stay on one storefront while receiving responses from the application responsible for each feature. [[1]](#ref-1)

The guide at the entrance in the illustration directs requests toward different Service doors, representing how hosts and paths determine destinations. Fig 1 shows how these rules translate into actual request paths.

![Store page and product lookup requests forwarded by an Ingress proxy to the target Pods of their Services](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/en/01-service-ingress-overview.png)

In Fig 1, requests from the browser visiting the store arrive at the Ingress proxy on Worker Node A. A **proxy** is a program that receives client requests and forwards them to a destination server. Page requests follow the blue path to a Pod selected by the page-serving Service. Requests for product names and prices follow the orange path to a Pod selected by the product lookup Service.

The Ingress declaration at the top relates request conditions to destination Services. The gray dashed lines below each Service identify its target Pod, while actual requests are forwarded to the Pod selected by the proxy. Users visit one store, but separate applications respond to requests for pages and product information.

After declaring this relationship, we need to configure the proxy that receives real requests to follow those rules.

### 1.2 The Ingress Manifest and Rule Configuration

Let us turn a page request in our store into configuration. If the site name is `example.com`, the page path is `/web`, and the page-serving Service is `web`, we can write the following. This **Ingress manifest** is the declaration of the request rules introduced above.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: default
spec:
  ingressClassName: example-ingress
  rules:
  - host: example.com
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

- `rules[].host: example.com`: The site name of the requested store.
- `path: /web` and `pathType: Prefix`: Select page requests for `/web` and its subpaths.
- `backend.service`: Specifies the **backend**, the destination for matching requests. Here, it points to port 80 of the `web` Service.

`ingressClassName` names the class used to select the responsible controller; Section 2.1 explains this relationship. This example assumes that the `example-ingress` class and a `web` Service in the same Namespace as the Ingress are available.

As when we submitted manifests to the API Server in Chapter 3, submitting this file stores an Ingress resource. An **Ingress controller** reads the stored request rules and Service target information, then incorporates them into the proxy configuration. The declared relationship, “send page requests for this site to this Service,” becomes actual request handling.

![An Ingress controller turning declarations into request paths](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/en/02-ingress-controller-flow.png)

At the top of Fig 2 are the control plane API Server and the stored declarations. Below them, an Ingress controller Pod runs on Worker Node A. Within that Pod, the controller updates configuration and the Ingress proxy receives external requests. The Pod on Worker Node B runs the application that handles forwarded requests.

When a user submits an Ingress, the API Server stores the declaration, and the controller on Worker Node A checks the updated rules and Service target information. It then configures the proxy in the same Pod with the destination Pod and port for `/web` requests. The gray dashed lines show how a declaration becomes request-handling configuration.

When an external request subsequently reaches the proxy along the orange path, the proxy compares its host and path with the configured rules. In this example, it forwards the request to `10.244.2.8:8080`, the Pod address on Worker Node B, and returns the Pod’s response to the client. Independently of this request handling, the controller continues watching the API for changes and updating the configuration.

An Ingress controller must be provisioned for the cluster environment. Some implementations run a proxy in a Pod, as shown here; others configure a cloud load balancer to handle requests. In either case, the implementation turns the request conditions and destinations declared in Ingress into actual request paths. [[2]](#ref-2)

## 2. Ingress Declarations and Service Connections

The Ingress manifest above references its responsible class and destination Service by name. Let us examine what these names connect. The class leads to the controller that applies the rules, while the Service name and port lead to the Pods that handle requests.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/interaction-ingress-services-v2.png" alt="Ingress matching tagged requests to their destination Services" width="70%" />

In the illustration, the guide directs a blue-tagged request to the Service with the matching tag and an orange-tagged request to a different Service. Matching colors and shapes represent the relationship between request conditions and destinations. The earlier manifest likewise specifies a site name and page path as conditions and selects the responsible Service as the backend.

### 2.1 Selecting the Ingress Controller for Request Rules

The manifest specifies which requests go to which Service. To make these rules work, an Ingress controller running in the cluster must read them and apply them to the entry point it manages. Along with the destination, we therefore need to identify **which controller should handle these rules**.

Imagine a store whose customer site is accessible over the internet while its staff administration site is available only on the company network. If separate entry points and controllers serve these sites, the customer Ingress should be assigned to the controller managing the public entry point, and the administration Ingress to the one managing the internal entry point.

**IngressClass** provides this connection. An IngressClass in the cluster contains identifying information for the controller responsible for that class. An Ingress selects it by putting the class name in `spec.ingressClassName`. The relationship **Ingress → IngressClass → responsible controller** determines which controller applies the request rules. [[1]](#ref-1)

Thus, `ingressClassName: example-ingress` in Section 1.2 means that the controller responsible for the `example-ingress` class should apply these rules. The following diagram illustrates this choice with customer and staff entry points.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/en/05-ingress-class.png" alt="Ingress resources linked through IngressClass to public-facing or internal controllers" width="100%" />

In Fig 3, the `shop` and `admin` Ingress resources in the same Namespace reference different classes. `public` leads to the public-facing controller, while `internal` leads to the internal-access controller. Each controller reads its assigned Ingress rules and applies them to its entry point. The names `public` and `internal` distinguish these roles; actual network settings determine whether an entry point is publicly accessible.

After choosing a class, we specify the application that its controller should reach. IngressClass is a cluster-scoped resource, while an Ingress looks up its destination Service in its own Namespace.

### 2.2 Service Name and Port References

Chapter 6 explained how a Service uses a selector to choose target Pods and connects its port to the application port on those Pods. Here, we use that same relationship to see how the Ingress in Section 1.2 references the `web` Service.

Assume a web application listens on port 8080 in Pods labeled `app: web` in the `default` Namespace. The Service selects Pods in this Namespace, and the Ingress resides in the same Namespace so that it can reference the Service name and port.

![Ingress Service name and port references connected to Service selectors and Pod ports](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/en/03-ingress-service-link.png)

Fig 4 shows how `backend.service.name` and `port` in Ingress reference a Service’s name and port, and how the Service selector and `targetPort` lead to the Pod labels and application port. The Service manifest paired with the earlier Ingress is as follows.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 8080
```

- `metadata.name: web` and `spec.ports[].port: 80`: The Service name and port referenced by Ingress as its backend.
- `spec.selector.app: web`: The label condition for Pods that should receive requests.
- `spec.ports[].targetPort: 8080`: The actual application port on the selected Pods.

This Service provides an internal access point. Since the Ingress entry point receives and forwards external requests, the application Service can remain `ClusterIP`, with Ingress referencing `web:80`.

### 2.3 From a Selected Service to Its Pods

With the destination Service declared, let us follow the request from the proxy to an actual Pod. This path depends on the controller implementation. If the Ingress proxy sends a request to the Service IP, it reaches a Pod through the Node forwarding rules configured by `kube-proxy`, as described in Chapter 6. Some implementations connect directly to Pods using addresses and ports from EndpointSlices; Figs 1 and 2 illustrate this path.

The Ingress proxy selects a backend by examining the HTTP request’s host and path, while `kube-proxy` configures Node rules that connect Service traffic to Pods. Regardless of the forwarding implementation, the Ingress declaration identifies its backend using a Service name and port.

The readiness checks from Chapter 4 and target address updates from Chapter 6 also fit into this path. When a web Pod is replaced, the EndpointSlice controller updates the addresses and readiness information associated with the Service, and the request path using that information is updated accordingly. The set of receiving Pods can change while the Ingress host and path rules stay the same. [[3]](#ref-3)

## 3. One Entry Point for Multiple Applications

The Ingress declaration now describes the connection to the web Service. Next, we will follow how a browser reaches the entry point using these rules and connect a product API to the same entry point.

### 3.1 Connecting a Domain to an External Entry Point

For a browser to use the Ingress rules, it needs an externally accessible entry point address. When the proxy runs in a Pod, as in the earlier diagrams, a `LoadBalancer` or `NodePort` Service from Chapter 6 provides a path for external requests to reach it.

Two Services with different responsibilities may appear here. The **Service exposing the controller’s proxy** carries external requests to the entry point, while the **application Service** identifies the web Pods that the entry point can select. In this arrangement, `web` and `api` can remain internal `ClusterIP` Services, with external access concentrated at the entry point.

The domain’s DNS records should point `example.com` to this external entry point. In Chapter 6, CoreDNS resolved Service names inside the cluster; here, the user’s browser resolves a site name to a public address. The Ingress `host` identifies HTTP requests that arrive at that address. Aligning DNS records with Ingress rules allows the entry point reached by the browser to select the correct application.

In a learning environment where the entry point is exposed at `192.0.2.10:80`, the following mapping can be placed in `/etc/hosts` on the computer sending the request instead of adding a DNS record.

```text
192.0.2.10 example.com
```

With this mapping, visiting `http://example.com/web` sends a request to port 80 at that IP address. If the controller is exposed through NodePort, include the **controller’s HTTP NodePort** in the URL. `/etc/hosts` maps names to IP addresses and does not specify ports.

### 3.2 Direct NodePort Requests and Requests Through Ingress

Comparing Ingress with the direct NodePort access from Chapter 6 makes the entry point’s role clearer. Previously, Ingress forwarded requests to Pods behind an internal Service. For this comparison, we make the application Service a NodePort Service, adding direct access to the same set of Pods. In Fig 5, the Ingress entry point is exposed on Node A’s port 80, and the application’s NodePort is exposed on port 30080.

When creating this comparison setup from scratch, the following command can create a NodePort Service connected to the `web` Deployment instead of using the earlier ClusterIP manifest. [[4]](#ref-4)

```bash
kubectl expose deployment web -n default --name web --type NodePort --port 80 --target-port 8080
```

```text
service/web exposed
```

The command creates a Service using the Deployment’s Pod selection criteria, with a NodePort assigned automatically. Fig 5 assumes that the assigned port is `30080`. With either Service type, the Ingress backend references Service port `80`.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/en/06-service-ingress-traffic.gif" alt="Direct NodePort and Ingress request paths to web Pods and their responses after configuration" width="100%" />

First, the controller applies Ingress rules to the proxy, while kube-proxy uses Service and EndpointSlice information to configure the Node’s forwarding rules. These components watch for changes and update their configurations independently. With these settings in place, we can compare the two paths taken by actual requests.

If the Node IP is `192.0.2.10`, a request to `http://192.0.2.10:30080/web` passes through the Node’s Service forwarding rules to a web Pod. This path does not evaluate Ingress host and path rules; the web application handles the `/web` request. In Fig 5, web Pod 1 receives it, and the response returns to the client along the path associated with that request.

By contrast, a request to `http://example.com/web` reaches port 80 of the Ingress entry point connected in Section 3.1. It carries the host `example.com` and path `/web`, which the proxy compares with its rules to select a Pod associated with `web:80`. In Fig 5, the proxy forwards directly to the address of web Pod 2 obtained from EndpointSlice information, and the response also returns through the proxy. Both routes select from the same web Pod set; in this example, the requests reach different Pods.

Both paths in this comparison reach the same application. The difference is how the destination is chosen: direct access uses the NodePort contacted by the client, while access through Ingress lets the proxy read the request’s host and path to select a destination Service.

### 3.3 Path-Based Services Within One Site

So far, Ingress has selected a single Service for web pages. Let us now add a product lookup Service, as in the store example from Section 1. Within the same `example.com` site, the existing page request and the new product lookup request use these paths.

- **`/web` — Store pages**: Requests a page to display in the browser. A web Pod associated with the `web` Service handles it.
- **`/api/items` — Product list**: Requests data such as product names and prices for the page. An API Pod associated with the `api` Service handles requests beginning with `/api`.

Both Services remain internal ClusterIP Services, while the Ingress entry point receives external requests.

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/en/07-ingress-routing.png" alt="One Ingress proxy selecting web and api Services by path and forwarding to their target Pods" width="100%" />

Fig 6 separates Service and Deployment into distinct resources above each Node. The Service selects receiving Pods by label, while the Deployment manages the application’s Pod replicas. Although the two resources target the same set of Pods, their responsibilities differ. The branching arrows from the proxy show forwarding to the application selected by the request path. Each arrow reaches a target Pod address discovered through its Service. Adding an `/api` rule to the existing `/web` rule produces this declaration.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: default
spec:
  ingressClassName: example-ingress
  rules:
  - host: example.com
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
```

- `paths`: The paths and destinations distinguished within the same host.
- Each `backend.service`: Connects `/web` requests to `web:80` and `/api` requests to `api:80`.

When the browser opens a page at `/web`, a web Pod responds. When that page requests `/api/items` to obtain the product list, an API Pod responds instead. The user stays on the same site address, while applications managed by separate Deployments handle the requests internally.

### 3.4 Path Matching and Precedence

In the declaration above, `/api/items` matches the `/api` rule because its `pathType` is `Prefix`. The following options determine how a request path is matched. [[1]](#ref-1)

- **`Prefix`**: Compares the prefix by path segments separated by `/`. A `/web` rule matches `/web` and `/web/item`, but not `/website`.
- **`Exact`**: Requires the entire path to match. A `/web` rule matches only `/web`, distinguishing it from `/web/` and `/web/item`.
- **`ImplementationSpecific`**: The controller implementation determines how paths are compared. Configure implementation-specific features according to its documentation.

When multiple paths within an Ingress match, the longest path takes precedence. If `/` and `/api` both use `Prefix`, the `/api` rule handles `/api/items`. For paths of equal length, `Exact` takes precedence over `Prefix`. Both matching types are case-sensitive.

Selecting a path and changing the forwarded path are separate operations. In the example, `/api/items` is forwarded unchanged, so the API application must handle that path. If the application handles only `/items`, configure the controller’s **path rewriting** feature to change the path before forwarding.

### 3.5 Different Hosts and Unmatched Requests

Destinations can also be separated by site name instead of path. To serve pages at `shop.example.com` and the product API at `api.example.com`, declare a separate `rules[].host` and backend for each name. Even if both DNS names point to the same entry point, the host in the HTTP request distinguishes their destinations.

When a rule specifies both host and path, both must match. If the only rule is for `example.com/web`, accessing the entry point by IP address may not select that rule because the request’s host differs from `example.com`. This is why resolving an address through DNS and matching the request’s host at the entry point must work together.

`spec.defaultBackend` can specify a destination for requests that match no rule. If it is omitted, the controller uses its default handling, often returning a 404 response. For example, when only `/web` and `/api` are declared, a request for `/help` falls back to this handling. [[1]](#ref-1)

By defining destinations for matching hosts and paths, along with handling for unmatched requests, we can serve multiple applications through a single entry point.

## 4. HTTPS Connections with a TLS Secret

The configuration above connects web pages and a product API to one site. If we add login or ordering features, information sent by the browser needs protection in transit. We can apply HTTPS to external access while retaining the existing routing rules.

### 4.1 HTTPS Entry Points and Certificates

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/interaction-ingress-key-lock.png" alt="Ingress holding a golden key beside a locked padlock" width="520" />

The key in the illustration represents the private key held by the HTTPS entry point, while the locked padlock suggests the protection provided by an encrypted connection. Receiving external requests securely requires preparation for encryption alongside the routing rules.

**HTTPS** protects HTTP requests and responses using a security protocol called **TLS**. Before sending a request, the browser checks the site’s certificate and establishes an encrypted connection. The HTTPS entry point therefore needs a certificate valid for the domain being accessed and the corresponding private key.

The certificate lets the browser verify the site’s identity, while the entry point keeps the private key secure and uses it to establish TLS connections. For `https://example.com/web`, we need a certificate valid for `example.com`. In Kubernetes, a Secret stores it so that the controller can read it.

### 4.2 Storing the Certificate and Private Key in a Secret

<img src="https://raw.githubusercontent.com/kubernetes/community/main/icons/svg/resources/labeled/secret.svg" alt="Official Kubernetes Secret resource icon" width="260">

Just as Chapter 3 separated sensitive application settings into Secrets, the certificate and private key are stored in a separate resource. A **TLS Secret** is a Secret of type `kubernetes.io/tls` that stores these two values under defined keys. The following structure stores them as `example-com-tls` in the same `default` Namespace as the Ingress. [[5]](#ref-5)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: example-com-tls
  namespace: default
type: kubernetes.io/tls
data:
  tls.crt: "<Base64-encoded certificate for example.com>"
  tls.key: "<Base64-encoded private key for the certificate>"
```

- `type: kubernetes.io/tls`: The Secret type for a certificate and private key.
- `data.tls.crt`: The site certificate.
- `data.tls.key`: The private key corresponding to the certificate.

Each file’s contents are Base64-encoded in `data`. Once the certificate and private key are stored in this Secret, Ingress can reference its name instead of repeating the file contents.

### 4.3 Certificate References and Request Forwarding

Adding `tls` settings to the `/web` and `/api` rules from Section 3 makes the same site available over HTTPS. The following declaration specifies that the certificate for `example.com` should be read from `example-com-tls` in the same Namespace.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: default
spec:
  ingressClassName: example-ingress
  tls:
  - hosts:
    - example.com
    secretName: example-com-tls
  rules:
  - host: example.com
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
```

- `spec.tls[].hosts`: The hostnames to which the certificate applies.
- `spec.tls[].secretName`: The name of the Secret storing the certificate and private key.

The requested name, `example.com`, must be covered by the certificate and aligned with both `tls.hosts` and `rules.host` in the Ingress. Fig 7 shows how these settings lead to HTTPS request handling.

![TLS Secret configuration, certificate verification, and encrypted requests and responses](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/en/04-ingress-tls.gif)

At the top of Fig 7, the controller checks the Ingress TLS settings, reads the certificate and private key from the referenced Secret, and configures the HTTPS entry point. Backend settings for hosts and paths are also prepared so that external requests can be accepted. This configuration happens before requests arrive, and the controller continues updating it when declarations or Secrets change.

Below, the browser connects to port 443 of the entry point and indicates the site name it wants to access. When the entry point presents the matching certificate, the browser checks the domain, issuer trust, and validity period, then establishes an encrypted connection.

Once that connection is ready, the browser sends a `/web` request along the blue path. Decrypting the traffic at the entry point to process the HTTP request is called **TLS termination**. The entry point examines the decrypted request’s host and path, selects the `web:80` backend, and forwards the request over HTTP to port 8080 of a ready web Pod along the orange path. The Pod’s response returns over HTTP, and the entry point encrypts it for delivery to the browser over their TLS connection. [[1]](#ref-1)

In Fig 7, HTTPS protects the segment between the browser and the entry point, marked with a padlock, while HTTP carries traffic between the entry point and the Pod. Handling external encryption at the entry point lets the application behind it retain its existing HTTP request handling.

## 5. Site Access Troubleshooting with kubectl

When a site is inaccessible, identifying where the request stops helps narrow down the settings to inspect. Chapter 5 traced Pod states to find causes; here, we follow the connections from the external entry point to the application. We will use `kubectl` to inspect the configuration and state of Ingress and related resources, then compare those results with the address being accessed and the observed errors. Finally, `curl` will show whether requests are being handled successfully through their HTTP response codes.

![Troubleshooting by connection, certificate verification, and application response failure](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/en/08-ingress-diagnosis.png)

Fig 8 organizes checks by where a request stops between connection and response. If the entry point cannot be reached, inspect the address and exposed port. If certificate verification fails, inspect the site name and certificate settings. If those stages succeed but the response is an error or is delayed, inspect request rules, Services, and Pod state.

### 5.1 Connection Failures: Address and Ingress Controller

If the browser cannot connect to the site, start by comparing the address resolved from the domain with the public Ingress address. The following is an example query result for the Ingress after applying the earlier HTTPS configuration.

```bash
kubectl get ingress web -n default
```

```text
NAME   CLASS             HOSTS         ADDRESS         PORTS     AGE
web    example-ingress   example.com   203.0.113.20    80, 443   5m
```

- `CLASS`: The IngressClass that handles the declaration. Check that the installed controller handles this class.
- `HOSTS`: The site name used to distinguish requests. Check that the browser requests `example.com`.
- `ADDRESS`: The external entry point’s IP address or hostname reported by the controller. The domain’s DNS records should lead to this entry point.

If the address is empty or the declared settings have not taken effect, check the controller’s running state and Ingress events. If an address is available but the connection times out, check whether the browser can reach port 443 at that entry point. Once a connection is established, a certificate error narrows the investigation to TLS configuration.

### 5.2 Certificate Errors: Site Name and TLS Secret

If the browser displays a certificate error, check whether the certificate presented by the entry point is valid for the requested site. Verify that it covers `example.com`, has not expired, and was issued by an authority the browser trusts.

Then check that the Ingress `secretName` references `example-com-tls` in the same Namespace. If it contains a different certificate, update the Secret with the correct certificate and corresponding private key, and check that the controller applied the change. Once certificate verification succeeds and an HTTP response is received, investigate host and path rules and the backend connection.

### 5.3 Error Responses: Ingress Rules and Target Pods

Even when a request reaches the entry point, a mismatched host or path prevents selection of the intended Service. For `https://example.com/web`, first check that the Ingress `host` is `example.com` and that a path rule matches `/web`.

If the rule matches, check that the referenced `web` Service exists in the same Namespace and exposes port `80`. Then check that its selector matches the web Pods’ labels and that EndpointSlices contain ready Pod addresses and application port `8080`. [[6]](#ref-6)

For example, even a running web Pod is normally excluded from request targets if the readiness probe from Chapter 4 fails. If no web Pods are ready, a correct Ingress rule still has no available backend to handle the request. Continue with the Pod state and log checks from Chapter 5 to find why the application is not ready.

When a response arrives, its HTTP status code can narrow the investigation. The following command displays only the status code instead of the response body. [[7]](#ref-7)

```bash
curl -o /dev/null -s -w "%{http_code}\n" https://example.com/web
```

- `200`: Indicates that the request was handled successfully.
- `404`: May appear when no Ingress rule matches or the application does not provide the requested path.
- `503`: May appear when there is no ready backend to receive the request.

For error responses, inspect both controller and application logs to determine which component returned the error. If calling the `web` Service from inside the cluster succeeds while external requests fail, focus on the entry point’s request rules and forwarding configuration.

An echo server that returns request information helps confirm which host and path the application actually received. The [Ingress examples](../Practice/Kubernetes/6.Ingress/) use this technique. Examining the response code together with the forwarded request details helps confirm that the request reached the intended application.

## Before Moving On

Here is what we covered in this chapter. Even when multiple applications run separately, users can access their features through one site. A shared entry point reads the requested name and path and directs each request to the appropriate application. Declaring this relationship in Ingress lets a controller apply it to actual request handling, so application execution and external request routing can be managed separately.

Handling HTTPS at the same entry point also protects communication between users and the site. Understanding how routing and connection protection fit together helps identify whether an access problem lies in establishing a connection, verifying a certificate, or receiving an application response.

We have now explored the basic Kubernetes resources and how they work together. Declaring an application’s desired running state leads the cluster to maintain that state, recover from problems, and forward requests to ready applications. The next step is to decide which resources and settings to use in a given situation.

<a href="https://www.cncf.io/training/certification/cka/">
<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/07/cka-official.svg" alt="Official CNCF Certified Kubernetes Administrator certification mark" width="220">
</a>

The **CKA** (Certified Kubernetes Administrator) is a Kubernetes administrator certification offered by the CNCF and the Linux Foundation. It is a practical exam in which candidates work with clusters from the command line to complete assigned tasks. It assesses operational skills such as application placement, networking and storage configuration, and troubleshooting. Beyond understanding concepts, candidates need to apply settings that meet requirements and verify the results. [[8]](#ref-8)

Chapters 8 through 16 will apply the concepts learned so far through practice problems modeled on the kinds of tasks covered by the CKA. Each chapter will develop the concepts needed for its problem, then explain how to read the requirements and why particular resources and settings are chosen. We will also verify the results of commands and manifests, building the ability to find solutions when conditions change.

The next chapter returns to the Pod lifecycle, connecting container restarts and Pod replacement to CKA-style practice problems. What must we prepare if an application needs its previously saved data after it starts again? Using this situation, we will examine which data disappears and which survives, then make the concepts concrete by configuring storage connections and checking recovery results.

## References

- <a id="ref-1"></a>[1] [Kubernetes documentation: Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- <a id="ref-2"></a>[2] [Kubernetes documentation: Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)
- <a id="ref-3"></a>[3] [Kubernetes documentation: EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)
- <a id="ref-4"></a>[4] [Kubernetes documentation: kubectl expose](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_expose/)
- <a id="ref-5"></a>[5] [Kubernetes documentation: TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)
- <a id="ref-6"></a>[6] [Kubernetes documentation: Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
- <a id="ref-7"></a>[7] [curl documentation: Command options](https://curl.se/docs/manpage.html)
- <a id="ref-8"></a>[8] [CNCF: Certified Kubernetes Administrator (CKA)](https://www.cncf.io/training/certification/cka/)
