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

### Running modules as docker containers
For each module, do the following (replace abc with the name of the module and 10.1.65.241 with IP address of the swarm manager)
```bash
echo docker -H 10.1.65.241:4000 run -dit --name abc --hostname abc --net ddag-net nehaljwani/ddag-base:latest /bin/bash
echo docker -H 10.1.65.241:4000 cp modules/abc abc:/
echo docker -H 10.1.65.241:4000 exec -d abc bash -c 'cd /abc ; hypnotoad api.pl'
```
For the public API end point, do: (replace 10.1.65.241 with IP address of the swarm manager)
```bash
echo docker -H 10.1.65.241:4000 run -dit --name public --hostname public --net ddag-net nehaljwani/ddag-base:latest /bin/bash
echo docker -H 10.1.65.241:4000 cp modules/public.pl public:/
echo docker -H 10.1.65.241:4000 exec -d abc bash -c 'hypnotoad public.pl'
```

### Querying distributed modules
To process the disconnected directed acyclic graph as shown in the picture above, create the file: `/tmp/input.txt` with the contents:
```bash
$ cat /tmp/input.txt
{
  "edges": {
    "input1": [
      "abc_1"
    ],
    "input2": [
      "abc_1"
    ],
    "input3": [
      "efg_1"
    ],
    "abc_1": [
      "bcd_1",
      "cde_1"
    ],
    "bcd_1": [
      "def_1"
    ],
    "cde_1": [
      "def_1"
    ]
  },
  "data": {
    "input1": "Hello! This is Nehal ",
    "input2": "Hi! This is J ",
    "input3": "Hola! This is Wani "
  }
}
```
and then type the following to find out the IP address of the container by the name 'public':
```bash
$ docker network inspect ddag-net
```
and finally, query it (replace 172.18.0.2 with the IP of the 'public' container). Sample run:
```bash
$ curl -s -H Expect: 172.18.0.2 --data "@/tmp/input.txt" | jq .
{
  "efg_1": "Hola! This Is Wani ",
  "input2": "Hi! This is J ",
  "bcd_1": "hi! this is j hello! this is nehal ",
  "abc_1": "Hi! This is J Hello! This is Nehal ",
  "cde_1": "HI! THIS IS J HELLO! THIS IS NEHAL ",
  "def_1": " LAHEN SI SIHT !OLLEH J SI SIHT !IH: lahen si siht !olleh j si siht !ih",
  "input3": "Hola! This is Wani ",
  "input1": "Hello! This is Nehal "
}
```

Happy DDAG-ing! :D
