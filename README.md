jenkins_node_manager
=======================

Jenkins Node Manager is a set of scripts that allow you to connect a node to a jenkins master and to controll scalling.  It can be used to connect a jenkins node to a specified master using JNLP for any unclaimed nodes listed on the master.  This works with jenkins systems that use authentication.  This is valuable when in a scenario where you want to be able to scale up or down nodes on a regular basis.

## Setup
1. On the master, create your nodes and set them up for Java web start connections.  I recommend you just make a bunch of copies of these so they can be used by nodes as you need them, unless you use the jenkins-cli.jar to create new nodes as needed.
2. From your node, you will need to set 4 environment variables

        JENKINS_HOSTNAME
        JENKINS_PORT
        JENKINS_USERNAME
        JENKINS_API_KEY
        
3. Run the connection script from the node.

        ruby connect_to_master.rb

You can also specify a node name to try to connect to...

        ruby connect_to_master.rb node12

__Recommended use:__ Have a startup script on your jenkins node that will

1. execute setting environment variables
2. cloneing this repo
3. Createing new nodes on jenkins (this can be done with jenkins-cli.jar)
4. and executing this script.

