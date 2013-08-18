jenkins_slave_connector
=======================

Jenkins Slave Connector is a simple ruby script that can be used to connect a jenkins slave to a specified master using JNLP for any unclaimed nodes listed on the master.  This works with jenkins systems that use authentication.  This is valuable when in a scenario when you want to be able to scale up or down slaves on a regular basis.

## Setup
1. On the master, your nodes created and setup for Java web start connections.  I recommend you just make a bunch of copies of these so they can be used by slaves as you need them.
2. From your slave, you will need to set 4 environment variables

        JENKINS_HOSTNAME
        JENKINS_PORT
        JENKINS_USERNAME
        JENKINS_API_KEY
        
3. Run the connection script from th slave.
        ruby connect_to_master.rb


* Recommended use: * Have a startup script on your jenkinsslave that will execute setting environment variables, cloneing this repo, and executing this script.
