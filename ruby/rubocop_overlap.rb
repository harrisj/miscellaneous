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
  'guides-style',
  'concourse-compliance-testing',
  'open-data-maker',
  'myusa',
  'about_yml',
  'compliance-viewer',
  'oauth2_proxy_authentication_gem'
]

class RubocopConfig
  def initialize(url)
    @config = {}
    load_from_url(url)
  end

  def load_from_url(url)
    begin
      yaml_content = open(url){|f| f.read}
    rescue OpenURI::HTTPError
      fail "Error fetching #{url}"
    end

    yaml = YAML::load(yaml_content)

    yaml.keys.each do |key|
      if key == 'inherit_from'
        yaml['inherit_from'].each do |file|
          new_uri = URI.join(url, file)
          load_from_url(new_uri)
        end
      else
        @config[key] ||= {}
        @config[key].merge!(yaml[key])
      end
    end
  end

  def rule_keys
    @config.keys - ['AllCops', 'inherit_from']
  end

  def rule_value_for_key(key)
    if @config.key?(key)
      conf = @config[key]
      if conf['Enabled']
        (conf['EnforcedStyle'] || conf['Max'] || conf['MaxLineLength'] || 'enabled').to_s
      else
        'disabled'
      end
    else
      nil
    end
  end

  def inspect
    @config.inspect
  end
end

class RubocopOverlap
  def initialize(repos)
    @repos = repos.dup
    @default_config = RubocopConfig.new('https://raw.githubusercontent.com/bbatsov/rubocop/master/config/default.yml')

    @rubocop_configs = {}
    @defined_keys = SortedSet.new
    @repos.each do |repo|
      full_repo_name = repo =~ %r{/} ? repo : "18F/#{repo}"
      yaml_url = "https://raw.githubusercontent.com/#{full_repo_name}/master/.rubocop.yml"
      @rubocop_configs[repo] = RubocopConfig.new(yaml_url)

      @rubocop_configs[repo].rule_keys.each {|k| @defined_keys << k }
    end
  end

  def report
    CSV.generate do |csv|
      csv << ['Rule', 'Rubocop Default'] + @repos

      @default_config.rule_keys.sort.each do |key|
        row = [key]

        row << @default_config.rule_value_for_key(key)

        @repos.each do |repo|
          repo_config = @rubocop_configs[repo]
          fail "Can't find config for #{repo}" if repo_config.nil?
          out = repo_config.rule_value_for_key(key)
          out += '*' if !out.nil? && out != @default_config.rule_value_for_key(key)
          row << out
        end

        csv << row
      end
    end
  end
end

puts RubocopOverlap.new(GITHUB_REPOS.sort).report
