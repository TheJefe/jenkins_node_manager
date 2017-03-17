jenkins_node_manager
=======================

Jenkins Node Manager is a set of scripts that allow you to connect a node to a jenkins master and to controll scaling.  It can be used to connect a jenkins node to a specified master using JNLP for any unclaimed nodes listed on the master.  This works with jenkins systems that use authentication.  This is valuable when in a scenario where you want to be able to scale up or down nodes on a regular basis.

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

## Scaling

This package gives you the ability to make automatic scaling decisions. There are X basic decisions that occur.

1. If there are Jenkins nodes that don't have a matching node in the passed in node name list argument, then delete them from Jenkins. This is done to keep the Jenkins node list in sync with the server host
2. If there are nodes in the name list argument that do not have a matching node in Jenkins, then trigger a delete node job to terminate that particular server. This is done to keep the remote server host in sync with the Jenkins nodes.
3. If there are jobs in the build queue that have not been picked up by a node, scale up that many nodes while staying within the `MAX_NODES` limit.
4. If the build queue is empty, and there are Jenkins nodes that are not busy, scale them down while staying within the limit set by `MIN_NODES`.

To use this feature, you'll need to have a couple of jobs configured.

1. Scaling decision making job

  This job will be responsible for running the scalr.rb script which will make the scaling decisions.

  This job will require these environment variables be set. They are listed with example values...

        HOSTNAME="jenkins.domain-name.com"
        PORT="8080"
        USERNAME="thejefe"
        API_KEY="12345"
        MIN_NODES=2
        MAX_NODES=50

  The execution of scalr.rb should include an argument which is a comma delimited list of Jenkins Node servers currently being hosted by your server provider, and will look like this..

        ruby bin/scalr.rb JenkinsMinion.1,JenkinsMinion.2,JenkinsMinion.3

2. Scaling up job

  This job must be named `Node-add` and accept the build parameter `NUM_NODES`.  This job will be responsible for telling your server provider to spin up 1 more server that is expected to connect to Jenkins on boot.

3. Scaling down job
  This job must be named `Node-delete` and accept the build parameter `NODE_NAME_TO_DELETE`.  This job will be responsible for
   1. Telling your server provider to spin down this server (the one this job is executing on)
   2. Trigger another job that will delete the Jenkins node

4. Delete a specified Jenkins node from Jenkins job

  This can be done through the jenkins-cli.  Doing this will look like this..

        java -jar jenkins-cli.jar -s ${JENKINS_URL} -i /home/jenkins/.ssh/id_rsa delete-node ${NODE_NAME_TO_DELETE}

### Nodes to be ignored for scaling purposes

Any node with a name containing DoNotMerge (case-insensitive) will be ignored by this script as it figures out how to scale
