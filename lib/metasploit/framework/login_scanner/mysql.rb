require 'metasploit/framework/tcp/client'
require 'rbmysql'
require 'metasploit/framework/login_scanner/base'
require 'metasploit/framework/login_scanner/rex_socket'

module Metasploit
  module Framework
    module LoginScanner

      # This is the LoginScanner class for dealing with MySQL Database servers.
      # It is responsible for taking a single target, and a list of credentials
      # and attempting them. It then saves the results.
      class MySQL
        include Metasploit::Framework::LoginScanner::Base
        include Metasploit::Framework::LoginScanner::RexSocket
        include Metasploit::Framework::Tcp::Client

        DEFAULT_PORT         = 3306
        LIKELY_PORTS         = [ 3306 ]
        LIKELY_SERVICE_NAMES = [ 'mysql' ]
        PRIVATE_TYPES        = [ :password ]

        def attempt_login(credential)
          result_options = {
              credential: credential
          }

          # manage our behind the scenes socket. Close any existing one and open a new one
          disconnect if self.sock
          connect

          begin
            ::RbMysql.connect({
              :host           => host,
              :port           => port,
              :read_timeout   => 300,
              :write_timeout  => 300,
              :socket         => sock,
              :user           => credential.public,
              :password       => credential.private,
              :db             => ''
            })
          rescue Errno::ECONNREFUSED
            result_options.merge!({
              status: :connection_error,
              proof: "Connection refused"
            })
          rescue RbMysql::ClientError
            result_options.merge!({
                status: :connection_error,
                proof: "Connection timeout"
            })
          rescue Errno::ETIMEDOUT
            result_options.merge!({
                status: :connection_error,
                proof: "Operation Timed out"
            })
          rescue RbMysql::HostNotPrivileged
            result_options.merge!({
                status: :connection_error,
                proof: "Unable to login from this host due to policy"
            })
          rescue RbMysql::AccessDeniedError
            result_options.merge!({
                status: :failed,
                proof: "Access Denied"
            })
          end

          unless result_options[:status]
            result_options[:status] = :success
          end

          ::Metasploit::Framework::LoginScanner::Result.new(result_options)
        end

        # This method sets the sane defaults for things
        # like timeouts and TCP evasion options
        def set_sane_defaults
          self.port = DEFAULT_PORT if self.port.nil?
          self.max_send_size = 0 if self.max_send_size.nil?
          self.send_delay = 0 if self.send_delay.nil?
        end

      end

    end
  end
end
