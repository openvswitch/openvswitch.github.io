---
layout: page
status: publish
published: true
title: Openvswitch Native tunneling configuration guide
author: Sugesh
date: 2015-10-23
categories:
- Uncategorized
tags: [vxlan, DPDK, tunneling]
comments: []
---

This guide is for configuring userspace tunneling in Open vSwitch. The
traditional OVS with kernel datapath uses kernel module to perform the tunneling,
however this setup performs all the tunneling operations purely in the
userspace. This way userspace-tunneling is platform independent.

This setup needs an additional bridge called “br-phy1” when compared to the
kernel based OVS. The purpose of this bridge is to make available the kernel
network stack for routing and arp resolution. The datapath needs to look-up
the routing table and arp table to prepare the tunnel header and xmit data to
the output port.

The tunneling setup is found as below:

    +--------------+
    |     VM-0     | 192.168.1.1/24
    +--------------+
       (vm_port0)
           |
           |
           |
           |
           |
    +--------------+
    |   br-int     |                           192.168.1.2/24
    +--------------+                          +--------------+
    |   vxlan0     |                          |    vxlan0    |
    +--------------+                          +--------------+
           |                                          |
           |                                          |
           |                                          |
           |                                          |
           |                                          |
           |                                          |
     172.168.1.1/24                                   |
    +--------------+                                  |
    |   br-phy1    |                            172.168.1.2/24
    +--------------+                          +---------------+
    | dpdk0/eth1   |==========================|      eth1     |
    +--------------+                          +---------------+
     Host A with OVS.                            Remote host.

#### Prerequisites
The host must be pre-installed with OVS-DPDK, QEMU and virtual machine images.
Please refer the installation guide of relevant modules for these instructions.
ovs-vswitchd and OVSDB server must be up and running before proceeding to any
of the configuration steps.

This setup guide covers only the required steps for setting up VxLAN userspace
tunneling. The same approach can be used for any other tunneling protocols, by
specifying the appropriate tunneling protocol type.

"eth1" interface on Host A is managed by kernel driver by default. The
interface must be attached to DPDK driver first, to perform the tunneling over
DPDK interface. Use the following script to bind "eth1" interface
to DPDK driver.

***HOST-A$ ./tools/dpdk_nic_bind.py --bind=igb_uio eth1***                  

"dpdk_nic_bind.py" is a utility script to bind/unbind interfaces to DPDK/Linux
kernel.More details on bind/unbind can be found at following link

 [bind/unbind network ports to DPDK](http://dpdk.org/doc/guides/linux_gsg/build_dpdk.html#binding-and-unbinding-network-ports-to-from-the-kernel-modules)

Note: This configuration guide is for setting up the VxLAN tunneling on one
host (local host). The same steps have to be performed on the remote host as well for
setting up a VM<->VM VxLAN tunnel setup. The only difference for setting up the
userspace-tunneling in remote node is, VM and VxLAN tunnel ip addresses are
different.

#### Configuration steps

1.	Create the “br-int” bridge as below,

    ***HOST-A$ ovs-vsctl --may-exist add-br br-int -- set Bridge br-int datapath_type=netdev --  br-set-external-id br-int bridge-id br-int -- set bridge br-int fail-mode=standalone***

2.	Add the VM interface to the “br-int”.

    ***HOST-A$ ovs-vsctl add-port br-int vm_port0 -- set Interface vm_port0 type=dpdkvhostuser***

    *[“vm_port0” is the vhost-user interface name for the VM0. This interface name
must be used while qemu starting the virtual machine.]*

3.	Start the VM(VM-0) using vhost-user network backend. The vhost-user
interface name is "vm_port0".

4.	Set the Ip address 192.168.1.1 to the VM interface. Run the following
command inside the VM to set the Ip address.

    ***VM-0$ ip addr add 192.168.1.1/24 dev eth0***

    *[“eth0” is the interface inside VM. It's possible to set the ip address using
"ifconfig" command as "ifconfig eth0 192.168.1.1/24". Please use either
one command to set the ip address.]*

5.	Attach the VxLAN tunnel interface to the “br-int“ bridge.

    ***HOST-A$ ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=172.168.1.2***

    *[“172.168.1.2” is the remote tunnel end point address, On remote host this
will be 172.168.1.1.]*

6.	Create the “br-phy1” bridge for attaching the physical interface.

    ***HOST-A$ ovs-vsctl --may-exist add-br br-phy1 -- set Bridge br-phy1 datapath_type=netdev -- br-set-external-id br-phy1 bridge-id br-phy1 -- set bridge br-phy1 fail-mode=standalone other_config:hwaddr="&lt;mac address of eth1 interface&gt;"***

    *[“eth1” is the physical interface on the host, Assign mac address of “eth1”
to the “br-phy1”.]*

7.	The physical port "eth1" can operate either as a kernel network
interface or a DPDK interface. Depending on the operating mode, attach "eth1"
to the "br-phy1" bridge as follows.

    Use step-7 if "eth1" is managed by kernel driver. Please follow step-8 rather than this step in case "eth1" is a DPDK Interface.This step will cause to loose the connectivity through “eth1” ([refer configuration problems in FAQ](https://github.com/openvswitch/ovs/blob/master/FAQ.md) for more details) for a while. The connectivity can be restored by moving the IP address to the “br-phy1” internal interface. The following command-set will do that,

    ***HOST-A$ ovs-vsctl --timeout 10 add-port br-phy1 eth1***

    ***HOST-A$ ip addr add 172.168.1.1/24 dev br-phy1***

    ***HOST-A$ ip link set br-phy1 up***

    ***HOST-A$ ip addr flush dev eth1 2>/dev/null***

    ***HOST-A$ ip link set eth1 up***

    ***HOST-A$ iptables –F***

8.	Steps for attaching “eth1” to “br-phy1” is slightly different in case
“eth1” is a DPDK interface. DPDK interfaces are not managed by the kernel, so
the port details are not visible on any “ip” commands.

    ***HOST-A$ ovs-vsctl --timeout 10 add-port br-phy1 dpdk0 -- set Interface dpdk0 type=dpdk***

    ***HOST-A$ ip addr add 172.168.1.1/24 dev br-phy1***

    ***HOST-A$ ip link set br-phy1 up***

    ***HOST-A$ iptables –F***

    *[“eth1” is mapped to DPDK port “dpdk0”. DPDK driver assign port names that
starts with “dpdk”]*

Now the traffic from “VM0” will be VxLAN encapsulated and send out over eth1/dpdk0
interface.

TCPDUMP doesn't work on DPDK interfaces(eth1) as its no longer managed by the kernel.

#### Debugging

* 	Verify the created tunnel port details.

     ***HOST-A$ ovs-appctl tnl/ports/show***

*	  As mentioned before, it's necessary that the vswitch should have the arp-table
entries to do tunneling at userspace. The learned arp entries in the vswitch
can be verified by,

      ***HOST-A$ ovs-appctl tnl/arp/show***

      the arp entries can be flushed using,

      ***HOST-A$ ovs-appctl tnl/arp/flush***

      To set a specific arp entry,

      ***HOST-A$ ovs-appctl tnl/arp/set &lt;bridge&gt; &lt;ip addr&gt; &lt;mac addr&gt;***

      In the above test setup, the following arp entries have to be set in case they are
 not present.

      ***HOST-A$ ovs-appctl tnl/arp/set br-int 172.168.1.1 &lt;mac addr of br-phy1&gt;***

      ***HOST-A$ ovs-appctl tnl/arp/set br-phy1 172.168.1.2 &lt;mac addr of remote TEP&gt;***

*	  Similarly OVS uses routing table entries to xmit the tunnel packets. The
vswitch routing entries can be verified by

      ***HOST-A$ ovs-appctl ovs/route/show***

      To delete the route entries.

      ***HOST-A$ ovs-appctl ovs/route/del***

*	  To lookup a route entry for a destination please use,

      ***HOST-A$ ovs-appctl ovs/route/lookup***

*   In case the route entries are missing for tunnel packet forwarding, it can be
added using the following command,

      ***HOST-A$ ovs-appctl ovs/route/add 172.168.1.1/24 br-phy1***

      This command instructs OVS to route all traffic destined for “172.168.1.2” to
 bridge “br-phy1”

*   To verify the range of tunneling source ports,

      ***HOST-A$ ovs-appctl tnl/egress_port_range***

*   To see the configured datapath ports,

      ***HOST-A$ ovs-appctl dpif/show***

*   To verify the flows programmed on the OVS datapath,

      ***HOST-A$ ovs-appctl dpctl/dump-flows***

      [This command shows how OVS forwards the packets in datapath.]
