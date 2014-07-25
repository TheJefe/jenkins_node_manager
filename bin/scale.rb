#!/usr/bin/env ruby

require 'json'
require File.expand_path("./../../lib/jenkins.rb", __FILE__)

MIN_NODES=ENV['MIN_NODES'].to_i
MAX_NODES=ENV['MAX_NODES'].to_i

# checks to make sure the required environment variables are set
def check_environment
  if HOSTNAME == nil || PORT == nil || USERNAME == nil || API_KEY == nil || MIN_NODES <= 0 || MAX_NODES <=0
    raise "environment variables not set. Please check that you have the following set...\
\nJENKINS_HOSTNAME\nJENKINS_PORT\nJENKINS_USERNAME\nJENKINS_API_KEY\nMIN_NODES\nMAX_NODES"
  end
  if ARGV.any?{ |s| s=~/pretend/ }
    puts "pretend flag detected"
  end

end

# Nodes that where passed in, that were not in the jenkins list of nodes should be shutdown
def clean_up_disconnected_remote_servers
  jenkins_node_names   = Jenkins.get_node_names
  jenkins_node_names  = jenkins_node_names.map(&:downcase)
  other_nodes_list = ARGV[0].split ','
  nodes_to_delete = other_nodes_list.reject{|x| jenkins_node_names.include? x}
  puts "Nodes that will be deleted: #{nodes_to_delete}"
  Jenkins.delete_nodes_by_name nodes_to_delete unless nodes_to_delete.empty?
end

def scale_nodes()
  node_info   = Jenkins.get_node_info
  build_queue = Jenkins.get_build_queue
  num_queued = build_queue["items"].count
  master_node = node_info["computer"].select {|x| x['displayName'] == "master"}.first
  master_executors = master_node["numExecutors"]
  total_executors = node_info["totalExecutors"] - master_executors
  # ugh, can't get a number of non master busy executors... so we will assume that 
  # the master executors are always busy and do our best
  busy_nodes = node_info["busyExecutors"] - master_executors

  busy_nodes = 0 unless busy_nodes > 0
  difference = total_executors - busy_nodes
  scale_by = 0

  puts "total_executors: #{total_executors}"
  puts "busy_nodes: #{busy_nodes}"
  puts "difference #{difference}"
  puts "queued jobs: #{num_queued}"

  if num_queued > 0 and num_queued > difference
    # don't go over the max count
    scale_by = (total_executors + num_queued) <= MAX_NODES ? num_queued : MAX_NODES - total_executors
  else # scale down, but by how much?
    if (total_executors - difference) >= MIN_NODES
      scale_by = -1 * difference
    else
      scale_by = -1 * ( total_executors - MIN_NODES )
    end
  end

  if scale_by > 0
    puts "scale up by #{scale_by}"
    Jenkins.add_nodes scale_by unless ARGV[0] =~ /pretend/
  else
    puts "scale down by #{ -1 *scale_by}"
    Jenkins.delete_nodes(-1 * scale_by) unless ARGV.any?{ |s| s=~/pretend/ }
  end
end

#### MAIN
check_environment
if ARGV.any?{ |s| s!=~/pretend/ }
  clean_up_disconnected_remote_servers
end
Jenkins.remove_disconnected_nodes
scale_nodes
