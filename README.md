# ddag-sample
A sample setup for processing non linear workflows using docker swarm

![ddag](https://cloud.githubusercontent.com/assets/1779189/14381786/a1d4c222-fda6-11e5-880b-82916d4a03fb.png)

### Base image for all modules
Either build the image:
```bash
$ docker build -t ddag-sample .
```
Or simply pull it:
```bash
$ docker pull nehaljwani/ddag-sample
```
### Setting up docker swarm

Either follow: https://docs.docker.com/engine/userguide/networking/get-started-overlay/
Or for a quick setup, do the following:
- Make sure that the docker daemon is launched with the required arguments on all host machines. 

    ```bash
    # For a machine running systemd, with network interface `ensp1s0` and IP address `10.1.65.241`, the line on the master host would look like:
    ExecStart=/usr/bin/docker daemon -H fd:// -H tcp://10.1.65.241:2375 --cluster-advertise enp1s0:2375 --cluster-store consul://10.1.65.241:8500
    #  Similarly, on a separate host, which is also supposed to host nodes of this swarm, running systemd, with network interface `eth0` and IP address `10.1.65.242`,  the line would look like:
    ExecStart=/usr/bin/docker daemon -H fd:// -H tcp://10.1.65.242:2375 --cluster-advertise eth0:2375 --cluster-store consul://10.1.65.241:8500
    ```
- Launch a key-value store on the master host:

    ```bash
    $ docker run -d -p 8500:8500 --name=consul progrium/consul -server -bootstrap
    ```
- Launch the swarm manager on the master host:

    ```bash
    $ docker run -d -p 4000:4000 swarm manage -H :4000 --replication --advertise 10.1.65.241:4000 consul://10.1.65.241:8500
    ```
        
- Join the swarm. For example, ...

    ```bash
    # The master host (10.1.65.241) would do:
    $ docker run -d swarm join --advertise=10.1.65.241:2375 consul://10.1.65.241:8500
    # The other host (10.1.65.242) would do::
    $ docker run -d swarm join --advertise=10.1.65.242:2375 consul://10.1.65.241:8500
    ```
- Create the overlay network on any one host (it will be available on all hosts which have joined the swarm): 

    ```bash
    $ docker network create -d overlay ddag-net
    ```
        
