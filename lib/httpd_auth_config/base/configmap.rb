require "base64"
require "yaml"

module HttpdAuthConfig
  class Base
    def generate_configmap(auth_type, auth_configuration, realm, file_list)
      config_map = auth_configmap_template(auth_type, auth_configuration, realm)
      file_specs = gen_filespecs(file_list)
      configmap_configuration(config_map, file_specs)
      configmap_file_list(config_map, file_specs)
      puts config_map.to_yaml
    end

    private

    def auth_configmap_template(auth_type, auth_configuration, kerberos_realms)
      {
        "data"     => {
          "auth-type"            => auth_type,
          "auth-configuration"   => auth_configuration,
          "auth-kerberos-realms" => kerberos_realms
        },
        "kind"     => "ConfigMap",
        "metadata" => {
          "name" => "httpd-auth-configs"
        }
      }
    end

    def gen_filespecs(file_list)
      file_specs = []
      file_list.each do |file|
        file = file.strip
        stat = File.stat(file)
        file_specs << {
          :basename => File.basename(file).dup,
          :binary   => file_binary?(file),
          :target   => file,
          :mode     => "%4o:%s:%s" % [stat.mode & 0o7777, stat.uid, stat.gid]
        }
      end
      file_specs.sort_by { |file_spec| file_spec[:basename] }
    end

    def configmap_configuration(config_map, file_specs)
      auth_configuration = "# External Authentication Configuration File\n#\n"
      file_specs.each do |file_spec|
        auth_configuration += "file = #{configmap_basename(file_spec)} #{file_spec[:target]} #{file_spec[:mode]}\n"
      end
      config_map["data"].merge!("auth-configuration.conf" => auth_configuration)
    end

    def configmap_file_list(config_map, file_specs)
      file_specs.each do |file_spec|
        content = File.read(file_spec[:target])
        content = Base64.encode64(content) if file_spec[:binary]
        # encode(:universal_newline => true) will convert \r\n to \n, necessary for to_yaml to render properly.
        config_map["data"].merge!(configmap_basename(file_spec) => content.encode(:universal_newline => true))
      end
    end

    def configmap_basename(file_spec)
      file_spec[:binary] ? "#{file_spec[:basename]}.base64" : file_spec[:basename]
    end
  end
end