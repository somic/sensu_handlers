# == Class: sensu_handlers::pagerduty
#
# Sensu handler for communicating with Pagerduty
#
class sensu_handlers::pagerduty inherits sensu_handlers {

  if $enable_filters {
    sensu::filter { 'page_true_only':
      attributes => {
        check => { page => true },
      },
    }
    $filters = [ 'page_true_only' ]
  } else {
    $filters = [ ]
  }

  ensure_packages(['rubygem-redphone'])
  sensu::handler { 'pagerduty':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/pagerduty.rb',
    config  => {
      teams => $teams,
    },
    require => [ Package['sensu-community-plugins'], Package['rubygem-redphone'] ],
    filters => $filters,
  }
  # If we are going to send pagerduty alerts, we need to be sure it actually is up
  monitoring_check { 'check_pagerduty':
    check_every => '60m',
    command  => '/usr/lib/nagios/plugins/check_http -S -H events.pagerduty.com -e 404',
    runbook  => 'http://y/rb-pagerduty',
    tip      => 'is PD up? https://events.pagerduty.com?',
  }

}
