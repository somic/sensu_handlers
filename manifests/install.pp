# == Class: sensu_handlers::install
#
# Install sensu handlers.
#
# == Parameters
#
# [*with_sensu_ruby_gems*]
# Install gems required by these sensu handlers with embedded ruby
# from sensu omnibus package. Defaults to true.
#
class sensu_handlers::install(
  $with_sensu_ruby_gems = true,
) {
  ensure_packages(['sensu-community-plugins'])

  if $with_sensu_ruby_gems {
    package { 'jira-ruby':
      ensure   => '0.1.9',
      provider => 'sensu_gem',
      require  => Package['sensu'],
    }

    package { 'redphone':
      ensure   => '0.0.6',
      provider => 'sensu_gem',
      require  => Package['sensu'],
    }
  }
}
