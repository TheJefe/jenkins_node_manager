require 'net/http'
require 'json'
require 'uri'
require 'open-uri'
require 'rexml/document'
require 'timeout'

hostname=ENV['JENKINS_HOSTNAME']
port=ENV['JENKINS_PORT']
@username=ENV['JENKINS_USERNAME']
@api_key=ENV['JENKINS_API_KEY']

@main_url="http://#{hostname}:#{port}"
@node_list_end_point= "/computer/api/json"

def http_get(end_point)
        uri= URI.parse "#{@main_url}#{end_point}"
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth(@username, @api_key)
        response = http.request(request)
        response.body
end

def download_client_jar
        puts "downloading slave.jar..."
        open('slave.jar', 'wb') do |file|
                file << open("#{@main_url}/jnlpJars/slave.jar").read
        end
        puts "download complete"
end

def get_secret(node_name)
        puts "downloading slave-agent.jnlp..."
        jnlp= http_get("/computer/#{node_name}/slave-agent.jnlp")
        doc = REXML::Document.new(jnlp)
        doc.get_text('jnlp/application-desc/argument')
end

def find_available_node
        node_name=nil
        nodes = JSON.parse http_get(@node_list_end_point)
        nodes["computer"].each do |i|
                if i["offline"]
                        node_name=i["displayName"]
                        break
                end
        end

        return node_name
end

download_client_jar

for i in 1..5
        node_name=find_available_node

        if node_name.nil? || !defined? node_name
                raise "no offline nodes found. goto #{@main_url} to create a new one"
        end

        puts "found available slot: #{node_name}"

        secret = get_secret(node_name)

        cmd = "java -jar slave.jar -jnlpUrl #{@main_url}/computer/#{node_name}/slave-agent.jnlp -secret #{secret} &"
        puts "starting jar file with: \n #{cmd}"
        fork{`#{cmd}`}
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
