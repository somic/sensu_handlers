require 'spec_helper'

describe 'sensu_handlers::jira', :type => :class do

  let(:facts) {{
    :osfamily => 'Debian',
    :lsbdistid => 'debian',
  }}

  basic_hiera = {
    'sensu_handlers::teams' => { 'operations' => { } }
  }

  filter_name = 'ticket_true_only'

  context 'by default' do
    let(:hiera_data) { basic_hiera }
    it {
      should_not contain_sensu__filter(filter_name)
      should contain_sensu__handler('jira').with_filters([ ])
    }
  end

  context 'with enable_filters' do
    let(:hiera_data) { basic_hiera.merge 'sensu_handlers::enable_filters' => true }
    it {
      should contain_sensu__filter(filter_name)
      should contain_sensu__handler('jira').with_filters([filter_name])
    }
  end

end

