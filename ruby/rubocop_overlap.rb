require 'rubygems'
require 'yaml'
require 'open-uri'
require 'set'
require 'csv'

GITHUB_REPOS = [
  'micropurchase',
  'dolores-landingham-bot',
  'identity-idp',
  'identity-dashboard',
  'c2',
  'open-data-maker',
  'myusa'
]

class RubocopOverlap
  def initialize(repos)
    @repos = repos.dup
    @rubocop_configs = {}
    @rubocop_keys = SortedSet.new

    @repos.each do |repo|
      full_repo_name = repo =~ %r{/} ? repo : "18F/#{repo}"

      begin
        yaml_url = "https://raw.githubusercontent.com/#{full_repo_name}/master/.rubocop.yml"
        yaml_content = open(yaml_url){|f| f.read}
        @rubocop_configs[repo] = YAML::load(yaml_content)
      rescue OpenURI::HTTPError
        fail "Error fetching #{yaml_url}"
      end

      @rubocop_configs[repo].keys.each {|k| @rubocop_keys << k unless k == 'AllCops' }
    end

  end

  def report
    CSV.generate do |csv|
      csv << [''] + @repos

      @rubocop_keys.each do |key|
        row = [key]

        @repos.each do |repo|
          repo_config = @rubocop_configs[repo]
          fail "Can't find config for #{repo}" if repo_config.nil?

          if repo_config.key?(key)
            conf = repo_config[key]
            if conf['Enabled']
              row << (conf['EnforcedStyle'] || conf['Max'] || conf['MaxLineLength'] || 'enabled')
            else
              row << 'disabled'
            end
          else
            row << nil
          end
        end

        csv << row
      end
    end
  end
end

puts RubocopOverlap.new(GITHUB_REPOS.sort).report
