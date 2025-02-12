require_relative 'command_line'

HelmPush::CommandLine::COMMANDS[:push] = Class.new do
  def run(params, compose)
    raise 'Compose file not defined' unless compose
    raise 'Version mask not defined' unless params[:'version-mask']

    compose['services'].each do |service_name, svc|
      next unless svc['build']
      unless svc['build']['tags']
        svc['build']['tags'] = [svc['image']]
      end

      svc['build']['tags'].each do |full_tag|
        _image, tag = full_tag.split(':')
        if tag =~ Regexp.new(params[:'version-mask'])
          puts "Package and Push Helm for the image #{full_tag}"

          system "helm package helm/#{service_name} --app-version #{tag} --version #{tag} --destination helm/" or raise("helm package failed")
          system "curl -u ${HELM_USER}:${HELM_PASSWORD} --upload-file helm/#{service_name}-#{tag}.tgz ${HELM_HOST}" or raise("helm push failed")
        end
      end
    end
  end

  def help = 'Package and Push Helm for each service'
end.new


