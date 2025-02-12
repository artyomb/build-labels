require_relative 'command_line'

def exec(cmd)
  system(cmd) or raise("Failed to run cmd:\n#{cmd}")
end

HelmPush::CommandLine::COMMANDS[:push] = Class.new do
  def run(params, compose)
    raise 'Compose file not defined' unless compose

    version_mask = params[:'version-mask'] || '\d+\.\d+\.\d+'
    compose['services'].each do |service_name, svc|
      next unless svc['build']
      unless svc['build']['tags']
        svc['build']['tags'] = [svc['image']]
      end
      puts "Helm push for service: #{service_name}"
      puts "Version mask: #{version_mask}"

      svc['build']['tags'].each do |full_tag|
        _image, tag = full_tag.split(':')
        puts "Image: #{_image}, Tag: #{tag}"

        if tag =~ Regexp.new(version_mask)
          puts "Package and Push Helm for the image #{full_tag}"

          exec "helm package helm/#{service_name} --app-version #{tag} --version #{tag} --destination helm/"
          exec "curl -u ${HELM_USER}:${HELM_PASSWORD} --upload-file helm/#{service_name}-#{tag}.tgz ${HELM_HOST}"
        else
          puts "Skip Helm package and Push for the tag #{tag}"
        end
      end
    end
  end

  def help = 'Package and Push Helm for each service'
end.new


