require 'puppet/provider/package/gem'

Puppet::Type.type(:package).provide :sensu_gem, parent => Puppet::Provider::Package::Gem do
    desc "Ruby Gem support for embedded ruby that ships with sensu omnibus package."

    commands :gemcmd => '/opt/sensu/embedded/bin/gem'
end
