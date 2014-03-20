#!/usr/bin/env ruby

require 'timeout'
require File.expand_path("./../../lib/jenkins.rb", __FILE__)

# Checks that the necessary environment variables are set
def check_environment
        if HOSTNAME == nil || PORT == nil || USERNAME == nil || API_KEY == nil
                raise "environment variables not set. Please check that you have the following set...\nJENKINS_HOSTNAME\nJENKINS_PORT\nJENKINS_USERNAME\nJENKINS_API_KEY"
        end
end

def connect
  ## this will attempt to connect 5 times before giving up
  for i in 1..5
    node_name= ARGV.empty? ? Jenkins.find_available_node : ARGV[0]
    puts node_name

    if node_name.nil? || !defined? node_name
      raise "no offline nodes found. goto #{MAIN_URL} to create a new one"
    end

    puts "found available slot: #{node_name}"

    secret = Jenkins.get_secret(node_name)

    cmd = "java -jar slave.jar -jnlpUrl #{MAIN_URL}/computer/#{node_name}/slave-agent.jnlp -secret #{secret} &"
    puts "starting jar file with: \n #{cmd}"
    fork{`#{cmd}`}
    # If the process does not return within 10 seconds, we assume that it has connected, otherwise we look for another node name and try again
    begin
      Timeout.timeout(10) do 
        Process.wait
      end
    rescue Timeout::Error
      puts "Connection appears to have been successful"
      exit 0
    end
    sleep 2
    pid = $?.pid
    result = `ps -p #{pid}; echo $?`.split("\n")[1]

    puts "results #{result}"
    if result.to_i == 0
      puts "connected to master successfully"
      exit 0
    else
      puts "failed #{i} times"
    end
  end
end

#### MAIN ####

check_environment
Jenkins.download_client_jar
connect
