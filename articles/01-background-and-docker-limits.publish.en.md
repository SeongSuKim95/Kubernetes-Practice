<!--
  English publish copy based on 01-background-and-docker-limits.draft.md.
  Image paths use GitHub raw URLs; diagrams use their English SVG variants.
  Image repository: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap01. The Origins of Containers and Docker

> This is the first article in a 15-week series. We trace the need for containers through bare metal servers and virtual machines, then explore the manual work involved in operating containers with Docker. We start with the basics so readers new to Docker can follow along.

## Introduction

![Official Kubernetes logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/02/en/01-k8s-logo.svg)

Containers and Docker are widely used in application development and deployment. Containers package an application with the environment it needs and run it in isolation; Docker is a major tool for building and running them. In Stack Overflow's 2025 Developer Survey, about 71% of respondents to the cloud development and infrastructure technology question reported using Docker during the previous year. Working with containers has become part of many developers' everyday work. [[1]](#ref-1)

To understand why these technologies became common, it helps to look at the problems that arise when an application moves from development to deployment and operation in another environment.

Imagine deploying a small discount banner for a shopping application. It works on the developer's computer, but the production server displays a blank page. The team says, “It works on my machine,” while looking for differences between the two environments.

Matching the environments does not end the operational work. An advertising campaign brings a surge of orders, requiring more servers with the same configuration. If payments stop working in the middle of the night, someone must inspect the logs and restart the application. Beyond developing features, teams need to **run applications consistently, scale with demand, and recover from failures**.

As an application splits into web, payment, and notification components, and the number of servers grows, doing all of this manually becomes difficult. Teams need ways to share server resources efficiently, prepare consistent runtime environments, and manage applications across servers.

This article follows the expansion of runtime environments and operational scope. We begin with physical servers and virtual machines, introduce containers and Docker, and then extend management to Compose and Swarm. A short Docker exercise demonstrates manual placement and recovery, setting the context for an orchestration platform such as Kubernetes.

## 1. One Application per Physical Server

![From virtualization to Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/01-journey.svg)

The diagram shows how the scope of application execution and management expands. Bare metal runs applications directly on a physical server. Virtual machines divide a server's resources among guest operating systems. Containers isolate application processes while sharing the host OS, and Docker Compose describes multiple containers on one server. Docker Swarm and Kubernetes extend management across servers, delegating container placement and recovery to a platform.

![Bare metal architecture](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/02-physical-server.svg)

The starting point is **bare metal**: a server whose operating system runs directly on physical hardware, without a virtualization layer. The stack consists of **hardware**, a **host OS**, and applications installed on that OS.

For a long time, running one application on each physical server was common. The structure is simple, and performance is straightforward because the OS and application use the hardware directly.

The operational limits are clear. Spare CPU and memory do not necessarily make it safe to add another application. Library versions, ports, and failure impact can overlap. An application that consumes too many resources can affect others on the same server. As applications multiply, buying servers, installing operating systems and applications, patching them, and handling failures all grow **with the number of servers**. Adding physical hardware also costs time and money.

This simplicity raises a question: can the unused resources on a server be shared more efficiently? That leads to the **virtual machine**.

## 2. Resource Sharing with Virtual Machines

![Virtual machine architecture](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/03-vm.svg)

A **virtual machine** (VM) runs above a **hypervisor** on physical hardware. The hypervisor divides the hardware among virtual computers, each with its own **guest OS**.

![Separate guest operating systems](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/13-vm-houses.svg)

Each VM has its own operating system and **kernel**, the core of that operating system. One physical machine acts as several separate computers.

VMs provide strong isolation between runtime environments. A problem in one VM is less likely to spread to another. A shopping site's web frontend, payment API, and product database can run in separate VMs on one server, reducing the waste of dedicating an entire physical server to each application.

However, a VM includes an operating system, much like copying an entire computer. This increases resource consumption and management overhead.

For example, a small API server may need only a few hundred megabytes of memory, while its guest OS requires several gigabytes of disk space and additional RAM. Running ten such applications on one physical server means maintaining ten operating systems as well. Deployment density improves over bare metal, but the unit is still larger than the application itself.

VM startup time also affects operations. When traffic briefly increases, a new VM may need to boot, configure networking, and verify packages before serving requests. A deployment cycle that includes preparing and starting a whole virtual machine slows the feedback loop for application changes.

Attempts to reproduce an environment can add more work. When local, test, and production environments differ, Node.js versions, libraries, and OS packages can drift. Copying a known-good VM can make them more consistent, but the copied unit includes an entire operating system. Transferring and starting it takes time, and every guest OS still needs patches and configuration updates. Changing one application can mean copying, deploying, and managing a whole computer.

VMs solve resource sharing, but remain relatively heavy for **lightweight application execution, rapid replication, and moving a consistent application environment**. The need to package only what an application requires leads to containers.

## 3. Consistent Environments with Containers and Docker

<img src="https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-container.png" alt="A container packages an application environment" width="40%" />

A container groups an application and its required runtime environment into one execution unit, as illustrated above.

![VMs and containers](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/04-vm-vs-container.svg)

Containers do not duplicate a guest OS. Application files and dependencies are packaged into an **image**, a blueprint containing the files needed for execution. A **container** runs processes from that image. The operating system of the computer running the containers is the **host OS**. Containers share the host's kernel while isolating their processes, making them lighter than VMs. [[2]](#ref-2)

Installing nginx, a web server, directly on different computers can produce differences in OS versions, packages, and configuration paths. Packaging its required files in an image gives containers created from that image the same paths and configuration. Using **the same image** across local, test, and production environments is a major benefit of containers.

![Official Docker logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/29-docker-official-logo.svg)

**Docker** makes container features already available in the Linux kernel easier to use. It was released as open source in 2013 by dotCloud, led by Solomon Hykes; the company became Docker Inc. that year. Docker provides images, a **CLI** (command-line interface), and a **registry** for storing and retrieving images.

![The docker run execution path](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/05-docker-flow.svg)

Isolating containers requires limiting what each process can see and which resources it can use. Each container also needs its own files. Docker builds this environment using Linux features.

Linux **namespaces** separate views of resources such as processes and networks. They allow containers to have isolated environments while sharing a kernel. Linux namespaces are different from Kubernetes Namespaces, which group Kubernetes resources.

**cgroups**, or control groups, govern resource usage such as CPU and memory. They are used to set limits on a container's resource consumption. [[3]](#ref-3)

A container also needs a filesystem that combines image files with changes made while running. **OverlayFS** is one way to combine several filesystem layers. The key point here is that each container gets a filesystem built on the files in its image; the internal implementation is beyond this introduction.

Users send commands such as `docker run` through the Docker client. The **Docker daemon**, a background management process, receives them and uses the container runtime to prepare isolation, resources, and filesystems, then run containers. Docker manages this process so users do not have to configure each kernel feature themselves. [[4]](#ref-4)

![Images and containers](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/06-image-vs-container.svg)

A **Dockerfile** records the instructions for building an image. Containers run from the resulting image. As the diagram shows, the same nginx image can produce several web server containers with different names and host ports.

We have distinguished the environment stored in an image from a running container. Before the exercise, we need one more concept: reaching a web server container from a browser or `curl` requires a **port** through which to send requests.

![Port publishing](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/11-port-mapping.svg)

A port is a **number** identifying a process or service that receives network traffic on a computer. Web servers, databases, and caches can share a machine while listening on different ports. A web server might listen on port **80 inside its container**, while a database uses port 3306.

Containers have a separate network environment from the host. nginx listening on port 80 inside a container does not automatically make it reachable on the host's port 80. Docker's `-p HOST_PORT:CONTAINER_PORT` connects the two. With `-p 8080:80`, requests to port 8080 on your computer are forwarded to port 80 in the container. [[5]](#ref-5)

The exercise will demonstrate downloading an image, creating a container, publishing a port, listing containers, and stopping and restarting one. Each command's options are explained where they are used.

## 4. Managing Multiple Containers with Compose and Swarm

`docker run` is enough to start a single container. Real applications often combine containers with different roles, such as web and database servers. Their configuration needs to be managed together; across multiple servers, placement and recovery need coordination too. We start with Docker Compose for a single server.

### 4.1 Single-Server Configuration with Docker Compose

![Official Docker Compose logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/30-compose-official-logo.svg)

**Docker Compose** defines a multi-container application in YAML and starts or stops its containers together. Version 1.0 was released in 2014, and it is now commonly used through the `docker compose` plugin in the Docker CLI.

![Docker Compose configuration](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/14-compose-menu.svg)

Repeatedly typing long `docker run` commands is error-prone and leaves a poor record of the setup. The illustrated `compose.yaml` describes the web, application, and database components together. **YAML** is a configuration format that uses indentation to express structure. `docker compose up` creates and starts containers from that configuration, making the same combination easier to reproduce. [[6]](#ref-6)

Compose is primarily designed for a **single host**. It organizes containers on one server rather than managing many servers as a cluster. If that server fails, the applications managed by Compose are also at risk.

### 4.2 Placement and Manual Recovery Across Servers

![The need for orchestration](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/32-why-orchestration.svg)

With multiple servers, operators must decide where each container belongs and where to restart work when a server fails, in addition to configuring execution on each host.

In the diagram, servers A and C continue running web, application, and database containers while server B has stopped. Operators must decide where to place web containers, how many to run, and who will restart containers that have exited. Distributing requests among web containers and finding them by a stable name when their IP addresses change add more work.

**Container orchestration** delegates these tasks to a platform that coordinates placement, recovery, and connectivity across servers.

### 4.3 Placement and Recovery with Docker Swarm

![Docker Swarm icon](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/31-swarm-official-logo.svg)

**Docker Swarm** is Docker's container orchestration system. Swarm mode has been part of Docker Engine since version 1.12 in 2016, allowing multiple servers to operate as a cluster that places and recovers services.

![Docker Compose and Docker Swarm](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/07-compose-to-swarm.svg)

A **node** is a server participating in the cluster. A **cluster** groups servers into one logical unit. The platform coordinates which nodes run containers and how to replace containers that exit. [[7]](#ref-7)

When an application managed with Compose expands across servers, orchestration such as Swarm extends management to placement and recovery between machines.

![Docker Swarm and Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/16-complex-vs-city.svg)

**Kubernetes** is also a container orchestration platform. Swarm supports service deployment, scaling, and rolling updates. Kubernetes provides more detailed declarations for operational policies such as autoscaling, communication boundaries, storage, and permissions, supported by a broad ecosystem of tools.

Next, we will examine the work required when operating containers directly with Docker commands, without orchestration.

## 5. Docker Exercise: Management After Startup

This exercise demonstrates that starting a container is only the beginning: recovery and image replacement still require work. It covers starting a web server, stopping and restarting it, and replacing images across several containers. Containers created in one step are reused in the next.

Docker must be installed and running; see the official installation guide [[8]](#ref-8) if needed. We assume host ports 8080–8083 are free. IDs and times in the outputs are illustrative.

### 5.1 Web Server Startup and Response Verification

![Starting a web server and publishing its port](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/17-lab-run.svg)

Start an nginx web server. Docker downloads the image first if it is not available locally.

```bash
# Start an nginx container and list running containers
docker run -d --name web-server-1 -p 8080:80 nginx:latest
docker ps
```

```text
<container ID>
CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES
a1b2c3d4e5f6   nginx:latest   Up 5 seconds   0.0.0.0:8080->80/tcp   web-server-1
```

`-d` runs the container in the background, and `--name` assigns its name. `-p 8080:80` publishes container port 80 on host port 8080. `Up` in the listing means the container is running.

Open `http://localhost:8080` in a browser to see the nginx welcome page. In a terminal, inspect the response headers with:

```bash
# Check the HTTP response from the web server
curl -I http://localhost:8080
```

```text
HTTP/1.1 200 OK
Server: nginx/...
...
```

`200 OK` means the web server successfully responded to the request.

### 5.2 Manual Recovery of a Stopped Container

![Stopping and manually restarting a container](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/18-lab-restart.svg)

Stop the container and check its state. `docker ps -a` includes stopped containers.

```bash
# Stop the container and inspect its exit state
docker stop web-server-1
docker ps -a
```

```text
web-server-1
CONTAINER ID   IMAGE          STATUS                      NAMES
a1b2c3d4e5f6   nginx:latest   Exited (0) 5 seconds ago    web-server-1
```

A container marked `Exited` cannot serve requests. A new browser request fails to connect. Because this exercise does not configure a restart policy, someone must start it again.

```bash
# Restart the stopped web server
docker start web-server-1
```

```text
web-server-1
```

Refresh the browser to confirm that the web server responds again.

Docker also offers restart policies for restarting exited containers on the same server. However, a manual `docker stop` does not cause an immediate policy-driven restart. A restart policy alone cannot create a replacement container on another server if the host itself fails. [[9]](#ref-9)

### 5.3 Manual Image Replacement Across Containers

![Manually replacing web server images](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/33-lab-image-replacement.svg)

Start three more web servers. They all listen on port 80 inside their containers, but each needs a distinct name and published port on the shared host.

```bash
# Start three more web servers from the same image
docker run -d --name web-server-2 -p 8081:80 nginx:latest
docker run -d --name web-server-3 -p 8082:80 nginx:latest
docker run -d --name web-server-4 -p 8083:80 nginx:latest
```

Each command returns a new container ID. `docker ps` shows four web servers. Choosing a name and port is repeated for every additional container.

Now replace the first web server's image with `nginx:alpine`. This selects a different image variant based on Alpine Linux; it is not a version-upgrade exercise. Stop and remove the old container, then create a new one with the same name and port.

```bash
# Replace the first web server with a different image
docker stop web-server-1
docker rm web-server-1
docker run -d --name web-server-1 -p 8080:80 nginx:alpine
```

```text
web-server-1
web-server-1
<new container ID>
```

Check that the first container's `IMAGE` is now `nginx:alpine` in `docker ps`. During replacement, no web server briefly serves port 8080. Replacing the other three requires repeating the same work for each one.

### 5.4 Cleanup and the Need for Operational Automation

When finished, stop and remove only the four containers created in this exercise.

```bash
# Remove the web servers created in this exercise
docker stop web-server-1 web-server-2 web-server-3 web-server-4
docker rm web-server-1 web-server-2 web-server-3 web-server-4
```

Each command prints the names of the containers it processed.

Images prepared the runtime environment, but a person still decided how many containers to maintain and when to restart or replace them. Repeating individual commands becomes difficult as the number of servers and containers grows.

Operations also requires distributing requests, detecting unresponsive applications, and preserving data after replacement. For now, recognizing these needs is enough; you do not need to master Docker networking or storage before continuing.

Kubernetes lets users declare the desired operational state, and its components work to maintain it. Our focus now shifts from starting containers to automating their ongoing management.

## Before the Next Article

This article covered the progression from VMs for sharing server resources, to containers and Docker for moving lightweight runtime environments, and then to Compose and Swarm as the number of containers grows.

The next article introduces Kubernetes, why it is useful, and how its core concepts fit together.

## References

- <a id="ref-1"></a>[1] [Stack Overflow 2025 Developer Survey: Docker usage](https://stackoverflow.co/company/press/archive/stack-overflow-2025-developer-survey/)
- <a id="ref-2"></a>[2] [Docker documentation: Containers and VMs](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)
- <a id="ref-3"></a>[3] [Docker documentation: Resource constraints](https://docs.docker.com/engine/containers/resource_constraints/)
- <a id="ref-4"></a>[4] [Docker documentation: Architecture](https://docs.docker.com/get-started/docker-overview/#docker-architecture)
- <a id="ref-5"></a>[5] [Docker documentation: Publishing ports](https://docs.docker.com/get-started/docker-concepts/running-containers/publishing-ports/)
- <a id="ref-6"></a>[6] [Docker Compose documentation](https://docs.docker.com/compose/)
- <a id="ref-7"></a>[7] [Docker Swarm documentation](https://docs.docker.com/engine/swarm/)
- <a id="ref-8"></a>[8] [Docker installation guide](https://docs.docker.com/get-started/get-docker/)
- <a id="ref-9"></a>[9] [Docker documentation: Restart policies](https://docs.docker.com/engine/containers/start-containers-automatically/)
