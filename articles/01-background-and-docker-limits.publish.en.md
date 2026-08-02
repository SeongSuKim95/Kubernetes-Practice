<!--
  English publish copy. Image paths use GitHub raw URLs. GFM Markdown (no HTML centering wrappers).
  Diagram SVGs point to images/articles/01/en/.
  Korean original: 01-background-and-docker-limits.publish.md
  Image repository: https://github.com/SeongSuKim95/Kubernetes-Practice
-->

# Chap01. Why Containers Appeared, and Docker

> This is the first post in a 15-week series. We cover why containers appeared—through Bare Metal and VMs—and then walk through the manual work people repeat when running containers with Docker. The article starts from what a container is, so readers new to Docker can follow along.

## Introduction

One Friday evening, you ship a small discount banner for a shopping app. It works fine locally, but the production server shows a blank page. Someone writes in chat: “It works on my machine.” Another day, an ad campaign works too well and orders pile up. Server CPU climbs, someone hastily rents a new server and copies settings over. At 3 a.m., an alert fires. The web is still up, but payments are down. You dig through logs and spend time deciding who will restart the payment service.

Anyone who has run a modern application can picture moments like these. Fixing a feature matters less than **where the app runs, how to keep the runtime environment the same, and who brings the app back when it dies**. Teams scale servers, copy environments, and pile up check scripts to survive that operations load. As apps split into web, payments, notifications, and databases, and as traffic swings hard, hand-driven operations stop keeping up.

Technology changed step by step to address that problem. Teams spread leftover server capacity, and virtual machines (VMs) became common. They tried to make “my machine and the server” match, and containers with Docker became familiar. Once execution units spanned many machines and many servers, placement and recovery moved onto a platform. At the end of that path, many teams meet the name Kubernetes. This article is preparation for that name: not memorizing it first, but following **why the operations problems above led through VMs and containers to handing placement and recovery to a platform**.

![Evolution from virtualization to Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/01-journey.svg)

The figure above is the full path we cover today. You will meet each technology name in the body of the article.

## 1. Starting point: one app on one physical server

![Bare Metal structure](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/02-physical-server.svg)

The path starts with **Bare Metal** (a server where the OS runs directly on physical hardware, with no virtualization layer). There is no virtual computer in the middle: **Hardware**, then a **Host OS**, then applications installed on top.

For a long time, putting one application on one physical server was the usual approach. The structure is simple and performance is intuitive, because the OS and app on the server use the hardware directly.

In real operations, the limits are clear. Even with spare CPU and memory, you cannot freely put another app on the same server. Library versions, ports, and failure blast radius get tangled. If one app consumes a lot of resources, other apps on the same server suffer too. As apps grow, buying new servers, installing OS and apps, applying patches to OS and apps, and handling failures all grow **with the number of servers**. The cost and time of adding physical machines grow with them.

Simplicity was a strength, but the question remained: “Can we share leftover capacity on this server more efficiently?” That question leads to the next step: the **Virtual Machine**.

## 2. Sharing leftover server capacity — Virtual Machine

![Virtual Machine structure](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/03-vm.svg)

A Virtual Machine (VM) places a **Hypervisor** on the physical hardware that once ran Bare Metal, then runs several virtual computers, each with its own **Guest OS**. The Hypervisor is the management layer that divides one machine’s hardware among many virtual computers. The Guest OS is the operating system installed separately inside each virtual computer.

![Virtual Machine structure, supplemental](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/13-vm-houses.svg)

Each VM has its own operating system and **Kernel** (the core of the OS). One physical server is split into multiple virtual computers.

Isolation is strong. A problem in one VM does not easily spread to another. On one physical server you can place a shopping-web VM, a payments-API VM, and a product-DB VM, and reduce the Bare Metal waste of “only one app per server.” Resource use improves compared with Bare Metal.

Still, a VM is closer to **copying a whole computer**. Using VMs for long enough piles up friction.

Imagine running a small API server. The application itself may need only a few hundred megabytes of memory, but starting a Guest OS already consumes gigabytes of disk and a fair amount of RAM. If you need ten similar apps on the same physical server, you are carrying **ten operating systems**, not just ten apps. Density is better than bare metal, but it is still far from “run only the app.”

VM boot time also shapes operations. When traffic spikes briefly and you want one more VM, you often wait through boot, network setup, and package checks before the VM joins the service. When deploy cycles stretch into “prepare a VM, put it on a server, verify it,” verifying a fix in production slows down with them.

Trying to match environments can make the work larger. If a developer’s local setup differs from test and production, Node.js versions, libraries, and OS packages drift. One honest response is “copy the working VM wholesale.” Environments can look alike. But the unit you move includes the whole OS, so size is large. Copying and booting VM replicas is slow, and security patches or config changes must be applied per Guest OS. To fix one app, you end up cloning, deploying, and managing a whole computer.

In short, VMs answered “share one server’s resources,” but they remained heavy for **running apps lightly, starting them quickly, and moving the same runtime environment at app granularity**. The need to package and move only the runtime the application needs—not a full OS—leads to the next step: the container.

## 3. Matching local and server runtimes — Container and Docker

![Learn Kubernetes with Seongsu: Container character](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/characters/character-container.png)

*Learn Kubernetes with Seongsu: Container character*

In this series, each core Kubernetes idea gets a character so the concept is easier to remember. The **Container** character you meet below will keep showing up in later posts. It is a guide for turning abstract names into scenes you can picture.

The Container character is a cube shaped like a shipping container. The `</>` mark on the front means it holds and runs application code. The corner braces suggest packing the needed runtime into one unit.

![VM vs Container comparison](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/04-vm-vs-container.svg)

A Container does not clone a Guest OS. It packs the application and the files it needs into an **Image** (a blueprint that bundles the files required to run). The process actually running from that image is called a **Container**. The OS of the real machine where containers run is the **Host** OS. Containers share the Host’s Kernel and isolate only processes. A Container is lighter than a VM and isolates apps as processes on the same Host.

If you install nginx (a web server program) directly on a local machine, OS versions, packages, and config paths differ per person. If you instead bundle what nginx needs into an Image, a Container started from that Image runs the web server with the same paths and layout. Local, test, and production servers may differ, but the appeal of containers is using the **same Image**.

![Docker official logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/29-docker-official-logo.svg)

**Docker** is the well-known tool that made this isolation—already available in the Linux Kernel—easy to use. Docker was open-sourced in 2013 by Solomon Hykes’s team at dotCloud; the company renamed itself Docker Inc. the same year. The core idea was packaging Linux Kernel container features behind an **Image**, a **CLI** (Command Line Interface), and a **registry** (a store from which you pull images).

![docker run flow](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/05-docker-flow.svg)

Containers look like a “dedicated environment” not because Docker invented a new OS, but because it bundled features the Linux Kernel already provided. Three names are worth remembering.

A **Namespace** splits the **space** a process sees. Process lists, networks, and mounted filesystems—“what is visible”—are separate per container. There is one Kernel, but inside a container it feels like a small private world.

**cgroups** (control groups) limit **amounts** such as CPU and memory. They stop one container from taking all Host resources. The same controls set per-container resource caps.

**OverlayFS** stacks Image layers so a container sees one root filesystem. An Image does not contain a kernel; it is closer to a **userspace** snapshot of the app, libraries, and config.

What users type in a terminal is usually the Docker Client (CLI). Creating containers is the job of the background Docker Daemon (a long-running management process). When you send `docker run`, the Daemon calls Namespace, cgroups, and filesystem setup to start the container. Think of Docker as a **management layer** on top of those kernel features.

![Image vs Container](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/06-image-vs-container.svg)

Docker’s philosophy, in short: keep the execution unit light, run the same image the same way anywhere, and capture the runtime as code such as a **Dockerfile** (a file that records the steps to build an image). It matters not to confuse Image and Container. An Image is a non-running blueprint; a Container is a process actually running from that blueprint. That is why you can start several web-server containers from the same nginx image.

That covers “what an Image builds, and what a Container actually runs.” One more idea before the labs: if you started a web-server container, you need a way to reach it from a browser or `curl`. That mechanism is a **port**.

![Port mapping](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/11-port-mapping.svg)

A port is a **number** that points to a process (or service) that accepts network requests on one machine. Even when web, DB, and cache share a server, different ports send requests to different targets. Many web servers listen on port 80 **inside** the container; databases often listen on 3306.

A container’s network space is separate from the host. So even if nginx listens on 80 inside the container, the host browser does not automatically reach that port 80. In Docker, `-p hostPort:containerPort` maps a host port to a container port. `-p 8080:80` means “forward requests that arrive on host port 8080 to port 80 inside the container.” The host opens 8080; inside the container, nginx still listens on 80.

In the labs you will confirm this with commands: pull an image, create a container, map a port, list containers, stop a container, then start that container again. You can read option details as each scenario needs them.

## 4. When containers span many machines and servers — Compose and Swarm

Starting one container works with `docker run`. Real services often run containers with different roles together, such as web and DB. Two tools appear here. **Docker Compose** defines multi-container setups on one server in a file and brings them up together. **Docker Swarm** places containers across servers and hands restarting dead containers to the platform. We start with the problem Docker Compose solves.

### 4.1 Bundling one-server setups in a file — Docker Compose

![Docker Compose official logo](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/30-compose-official-logo.svg)

**Docker Compose** defines multi-container applications in YAML and starts or stops them together. Version 1.0 shipped in 2014; today it is often used as the `docker compose` plugin with the Docker CLI.

![Docker Compose](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/14-compose-menu.svg)

Typing long `docker run` lines repeatedly is error-prone, and it is hard to record “which containers started in which order.” Docker Compose writes that layout in one **YAML** file (a config format structured by indentation) and brings everything up with `docker compose up`. With the file alone, the same combination is easy to reproduce.

Docker Compose still assumes a **single host** (one server) by default. It organizes containers on one machine; it is not a tool for operating many servers as one cluster. If that one server fails, the Compose-defined services are at risk with it.

### 4.2 Across many servers, people still place and recover by hand

![Why orchestration is needed](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/32-why-orchestration.svg)

When you add servers or run several containers of the same role, a single-server config file is not enough. It is like stocking goods in several warehouses and still calling someone for every order to decide which warehouse ships.

Picture servers A and C running web, app, and DB containers, while server B is down. People must decide by hand each time: which server gets the web container, how many web replicas to run, and who restarts a dead container. Spreading requests across web containers, and finding containers by service name when IPs change, add the same burden.

The layer that hands this operations work to a platform is **Container Orchestration**. It automatically coordinates placement, recovery, and connectivity for containers across servers.

### 4.3 Handing placement and recovery to the platform — Docker Swarm

![Docker Swarm icon](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/31-swarm-official-logo.svg)

**Docker Swarm** is Docker’s container orchestration. From Docker Engine 1.12 in 2016, Swarm mode is built into the engine, so you can treat several servers as one cluster and place or recover services.

![Docker Compose and Docker Swarm](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/07-compose-to-swarm.svg)

Several **Nodes** (servers that join a cluster) form a **Cluster** (many servers treated as one logical unit). The platform decides which node runs a container and restarts a container when it dies.

Roles split cleanly. Docker Compose is strong at **declaring and starting multi-container setups on one server**. Docker Swarm helps **place and recover containers across servers and adjust service size**. Teams often use Docker Compose for local or small setups, then need orchestration such as Docker Swarm once they have many servers.

![Docker Swarm and Kubernetes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/16-complex-vs-city.svg)

**Kubernetes** is the same kind of **container orchestration** as Docker Swarm. Both hand placement across servers, restarting dead containers, and adjusting service size to a platform. In practice you still meet Kubernetes more often, because it offers **more ways to declare and enforce operations policy** than Docker Swarm.

Docker Swarm can deploy services, scale them, and do basic zero-downtime replacement (rolling updates). Kubernetes adds richer ways to **declare and enforce** resource requests and limits, autoscaling, network rules, storage, and permissions. As a result, many monitoring and deploy tools assume Kubernetes.

This article does not go into Kubernetes features in detail. **Today** we close this section by walking through the manual work people repeat when running containers with Docker. The labs below make that work concrete.

## 5. Docker’s limits become clear when you place and recover by hand

Reading only about Docker Swarm vs Kubernetes rarely makes the need for Kubernetes feel concrete. To understand the difference, it helps to first see **what people repeat in Docker operations when there is no automation**. The labs below are for that. The goal is not memorizing commands; it is noticing the work you must do by hand when containers die, grow, or change. At the end of each scenario, one or two sentences connect how the **same problem looks different** in Kubernetes.

Docker must be installed. (If it is not, follow the official Docker install guide until the CLI works.)

```bash
# Check that the Docker CLI is ready in the lab environment
docker --version
```

```text
Docker version 27.x.x, build ...
```

If you see a version, the CLI is ready.

### 5.1 Basic run and status checks

![Scenario 1: basic run](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/17-lab-run.svg)

Start a web-server container in the background. `-p 8080:80` maps host port 8080 to port 80 inside the container (where nginx listens). If the image is not local, Docker pulls it from a registry.

```bash
# Scenario start: run an nginx web server to see basic operations
docker run -d --name web-server-1 -p 8080:80 nginx:latest
```

```text
Unable to find image 'nginx:latest' locally
...
Status: Downloaded newer image for nginx:latest
a1b2c3d4e5f678901234567890abcdef1234567890abcdef1234567890abcd
```

Confirm the container is running and check logs and status.

```bash
# Check the web server you just started via list, logs, and status
docker ps
docker logs web-server-1 | head -5
docker inspect web-server-1 --format='{{.State.Status}}'
```

```text
CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES
a1b2c3d4e5f6   nginx:latest   Up 5 seconds   0.0.0.0:8080->80/tcp   web-server-1

/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
...
running
```

`docker ps` shows running containers only; `docker ps -a` includes stopped ones. `Up` in `STATUS` means the container is shown as **running**. `Exited` means it has stopped. `logs` and `inspect` let you look closer. In Kubernetes, listing, logs, and status feel similar, but the platform takes on more of **keeping the desired container count**.

```bash
# Confirm port mapping with an HTTP status code
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080
```

```text
200
```

### 5.2 Detecting exit and recovering by hand

![Scenario 2: manual recovery](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/18-lab-restart.svg)

Stop the container. With default settings, a stopped container does not come back on its own.

```bash
# Stop the container yourself to show there is no automatic recovery
docker stop web-server-1
docker ps -a --filter name=web-server-1
```

```text
web-server-1

CONTAINER ID   IMAGE          STATUS                     NAMES
a1b2c3d4e5f6   nginx:latest   Exited (0) 5 seconds ago  web-server-1
```

```bash
# After stopping the container, confirm the service is down
curl -s -o /dev/null -w "%{http_code}\n" --max-time 3 http://localhost:8080 || echo "failed"
```

```text
failed
```

A person starts the stopped container again.

```bash
# A person starts the stopped container again
docker start web-server-1
docker ps --filter name=web-server-1
```

```text
web-server-1

CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES
a1b2c3d4e5f6   nginx:latest   Up 2 seconds   0.0.0.0:8080->80/tcp   web-server-1
```

You can pass `--restart=always`, but if the **server** (node) itself dies, that option alone does not move the container to another server. In Kubernetes, when a container dies or a server leaves, the platform **restores the desired container count on another server**.

### 5.3 Multiple containers and manual updates

![Scenario 3: manual update](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/19-lab-multi-update.svg)

Start more web servers of the same role. Each needs its own host port.

```bash
# Manual scale: grow web servers one port at a time
docker run -d --name web-server-2 -p 8081:80 nginx:latest
docker run -d --name web-server-3 -p 8082:80 nginx:latest
docker run -d --name web-server-4 -p 8083:80 nginx:latest
docker ps --filter "name=web-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

```text
NAMES           STATUS          PORTS
web-server-4    Up 3 seconds    0.0.0.0:8083->80/tcp
web-server-3    Up 4 seconds    0.0.0.0:8082->80/tcp
web-server-2    Up 5 seconds    0.0.0.0:8081->80/tcp
web-server-1    Up 2 minutes    0.0.0.0:8080->80/tcp
```

Now assume only `web-server-1` moves to a new image. You stop it, remove it, and run a new one yourself.

```bash
# Manual update: change the image per container with stop/rm/run
docker stop web-server-1
docker rm web-server-1
docker run -d --name web-server-1 -p 8080:80 nginx:1.21
docker ps --filter "name=web-server" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

```text
web-server-1
web-server-1
...
NAMES           IMAGE         STATUS
web-server-1    nginx:1.21    Up 3 seconds
web-server-4    nginx:latest  Up 1 minute
web-server-3    nginx:latest  Up 1 minute
web-server-2    nginx:latest  Up 1 minute
```

Repeating the same work for the other three containers means some ports go down during the update, and rolling back to the previous image version is also per container. In Kubernetes, you put the new version in a **manifest** (a config file that records the desired state); the platform replaces containers in order and usually makes rollback to the previous settings easier.

### 5.4 Out of memory

![Scenario 4: OOM Kill](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/20-lab-oom.svg)

This time, give a tiny memory limit on purpose and check whether the kernel kills the process when the limit is exceeded. (This lab command only creates a “sudden memory load”; you do not need to memorize every option.)

```bash
# Resource limit: see OOM when the memory cap is too low
docker run -d --name memory-test --memory=10m --memory-swap=10m \
  alpine sh -c "tail -f /dev/null & sleep 1 && dd if=/dev/zero of=/dev/null bs=1M"
sleep 3
docker ps -a --filter name=memory-test
docker inspect memory-test --format='OOMKilled={{.State.OOMKilled}} Status={{.State.Status}}'
```

```text
...
NAMES          STATUS
memory-test    Exited (137) 2 seconds ago

OOMKilled=true Status=exited
```

`OOMKilled=true` means the kernel likely killed the process after it hit the memory limit. Docker can set a memory limit, but when memory is short it does not raise the limit or move the container to another server. Giving a larger limit and starting the container again is still manual.

```bash
# Raise the memory limit and restart to see the container stay healthy
docker rm memory-test
docker run -d --name memory-test --memory=100m --memory-swap=100m \
  alpine sh -c "tail -f /dev/null"
docker ps --filter name=memory-test
```

```text
memory-test
...
NAMES          STATUS
memory-test    Up 2 seconds
```

In Kubernetes, you record each container’s resource range in a manifest, and if one server cannot host it, the platform **can place the container on another server**.

### 5.5 Sketching load balancing by hand

![Scenario 5: load balancing](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/21-lab-lb.svg)

Right now each web server has a different host port.

```bash
# List the host ports to put behind a load balancer
docker ps --filter "name=web-server" --format "table {{.Names}}\t{{.Ports}}"
```

```text
NAMES           PORTS
web-server-1    0.0.0.0:8080->80/tcp
web-server-2    0.0.0.0:8081->80/tcp
web-server-3    0.0.0.0:8082->80/tcp
web-server-4    0.0.0.0:8083->80/tcp
```

Users must remember ports 8080 through 8083, and splitting traffic needs a separate load balancer (a device that spreads requests across servers) in front. A front-end config that lists “where to send traffic” looks roughly like this. (`host.docker.internal` is a name containers use to reach your machine.)

```nginx
# Example config showing the front end must list web-server ports by hand
upstream backend {
    server host.docker.internal:8080;
    server host.docker.internal:8081;
    server host.docker.internal:8082;
    server host.docker.internal:8083;
}
server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
```

Whenever containers are added or removed, you must edit this file and restart the load balancer. Kubernetes is designed so the platform **tracks the live container list** and spreads requests, so people do not rewrite that list every time.

This scenario is for the concept; you do not need to start a load-balancer container. The point is that **whenever the set of backends changes, a person must edit the load-balancer config**.

### 5.6 Manual scale-out

![Scenario 6: manual scale](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/22-lab-scale.svg)

Scale-out means growing the number of same-role containers to handle traffic. Assume traffic rose and start three more web servers. You also choose the ports yourself.

```bash
# Start more web servers to show the upstream target list grows by hand
docker run -d --name web-server-5 -p 8084:80 nginx:latest
docker run -d --name web-server-6 -p 8085:80 nginx:latest
docker run -d --name web-server-7 -p 8086:80 nginx:latest
docker ps --filter "name=web-server" --format "{{.Names}}" | wc -l
```

```text
...
7
```

To shrink container count you repeat stop/rm again, and you must update the load-balancer config too. Container count does not rise and fall automatically with CPU use. In Kubernetes you can **record the desired container count in a manifest**, or let load automatically adjust container count.

### 5.7 Container running, web server dead

![Scenario 7: process death](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/23-lab-zombie.svg)

Earlier, `Up` in `docker ps` meant the container was running. That status alone does not guarantee “the web server inside can accept requests.” Force-kill nginx inside `web-server-2` to see the gap.

```bash
# Reproduce a running container whose web server alone is dead
docker exec web-server-2 pkill nginx || true
sleep 2
docker ps --filter name=web-server-2
docker exec web-server-2 ps aux || echo "no process list"
```

Depending on the environment, `docker ps` may still show `Up` (running) while the web server inside is gone and cannot answer requests.

```text
NAMES           STATUS
web-server-2    Up 3 minutes

...
(nginx master/worker may be missing, or exec may fail)
```

Docker can add a **health check** with `--health-cmd` (a periodic check that the service inside can accept requests), but a failed check does not, by default, start a new container. For now a person restarts the container.

```bash
# Without health-check automation, a person restarts the container
docker restart web-server-2
docker ps --filter name=web-server-2
```

```text
web-server-2
NAMES           STATUS
web-server-2    Up 3 seconds
```

Kubernetes separates “is the container up?” from “is it ready for requests?” and, on failure, restarts the container or sends requests to another one.

### 5.8 Container networking and service discovery

![Scenario 8: service discovery](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/24-lab-discovery.svg)

Service discovery means finding a peer container by a stable name, not a changing IP. Start a database container, read its IP, then try connecting from another container with that IP.

```bash
# Service discovery: create a case where you must look up the DB IP yourself
docker run -d --name mysql-db \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=testdb \
  mysql:8.0
sleep 8
DB_IP=$(docker inspect mysql-db --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "MySQL IP: $DB_IP"
```

```text
...
MySQL IP: 172.17.0.x
```

Hard-coding the IP means you must update config when the container is recreated and the address changes. A user-defined network makes name-based connections better.

```bash
# Join a user-defined network for name-based connections
docker network create app-network
docker network connect app-network mysql-db
docker run -d --name app-server --network app-network \
  -e MYSQL_HOST=mysql-db \
  alpine sh -c "apk add --no-cache mysql-client >/dev/null && tail -f /dev/null"
docker exec app-server sh -c 'echo MYSQL_HOST=$MYSQL_HOST'
```

```text
app-network
...
MYSQL_HOST=mysql-db
```

You still manage the network and container attachments by hand. Kubernetes lets apps find peers by a **stable service name**, so you change app config less when container IPs change.

### 5.9 Without a volume, delete means data is gone

![Scenario 9: volumes](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/25-lab-volume.svg)

A Volume is storage outside the container for data that should survive container deletion. First delete a database created without a volume, and confirm the data disappears with it.

```bash
# Show that deleting a container without a volume removes its data
docker stop mysql-db
docker rm mysql-db
echo "mysql-db removed (data in container filesystem is gone)"
```

```text
mysql-db
mysql-db
mysql-db removed (data in container filesystem is gone)
```

Data that lived only in the container’s writable layer disappears with the container. For persistence, create a volume and mount it into the container.

```bash
# Attach a volume and start MySQL again so data can persist
docker volume create db-data
docker run -d --name mysql-db \
  -v db-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=testdb \
  mysql:8.0
docker volume inspect db-data --format='Name={{.Name}} Mountpoint={{.Mountpoint}}'
```

```text
db-data
...
Name=db-data Mountpoint=/var/lib/docker/volumes/db-data/_data
```

Docker volumes work, but people still design creation, backup, and sharing across servers. Kubernetes handles this more by **requesting storage in a manifest and using what the platform provides**.

### 5.10 Gathering the limits in one place

![Scenario 10: limits summary](https://raw.githubusercontent.com/SeongSuKim95/Kubernetes-Practice/main/images/articles/01/en/26-lab-summary.svg)

Matching what you just experienced to the background earlier makes the relationship clear.

Without automatic recovery, people repeat `docker start` to bring containers back. With manual scaling, ports and load-balancer config must change together. Without load balancing and service discovery, people manage front-end target lists and container IPs. Weak health checks make it easy to miss “container running, web server dead.” Image replacement (rolling updates) is stop/rm/run per container. Resource limits can be set, but the platform does not automatically re-place containers. Data only survives if you remember volumes.

Kubernetes has you declare the desired state, then the platform reduces the gap to the actual state. Recovery, load distribution, and service discovery—the work you did by hand above—move closer to the platform’s job.

## Before the next post

Here is what this article covered. VMs appeared to share server resources; Containers and Docker appeared to move runtimes lightly; as containers grew, Docker Compose and Docker Swarm became necessary.
The next article outlines what Kubernetes is, why to learn it, and how the core ideas connect.
