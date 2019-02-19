## frozen_string_literal: true
# cd code; bundle install --without development test --path vendor/bundle; zip -r ../advent-bot.zip function.rb vendor) && aws lambda update-function-code --function-name advent-bot --zip-file fileb://advent-bot.zip
require 'date'
require 'json'
require 'aws-record'

VALID_DATES = (Date.new(2015, 12, 1)..Date.today).select { |d| d.month == 12 && d.day < 26 }
VALID_DATE_STRINGS = VALID_DATES.map(&:iso8601)

class AdventBot
  include Aws::Record
  set_table_name ENV['DynamoDBTable']

  client_opts = {}
  client_opts['endpoint'] = 'http://host.docker.internal:8000' if ENV['AWS_SAM_LOCAL'] == 'true'
  configure_client client_opts

  string_attr :SlackOrg, hash_key: true
  list_attr   :Finished

  def random
    dates_left = VALID_DATE_STRINGS - self.Finished
    return ":star: all problems completed :star:" if dates_left.length.zero?

    self.Finished << dates_left.sample
    selected = Date.parse(self.Finished.last)
    save

    "https://adventofcode.com/#{selected.year}/day/#{selected.day}"
  end

  def status
    response = ''

    9.times { response << christmas_character }

    response << ":zero::one::two::three::four::five::six::seven::eight::nine::zero::one::two::three::four::five:\n"
    response << ":one::two::three::four::five::six::seven::eight::nine::zero::one::two::three::four::five::six::seven::eight::nine::zero::one::two::three::four::five:\n\n"

    (VALID_DATES.first.year..VALID_DATES.last.year).each do |year|
      (1..25).each do |day|
        response << if self.Finished.include?("#{year}-12-#{day.to_s.rjust(2, '0')}")
                      ':star:'
                    else
                      ':black_small_square:'
                    end
      end
      response << "\n"
    end

    response << "\n"
    christmas_emojis = [':deer:', ':cookie:', ':gift:', ':glass_of_milk:', ':snowman:', ':christmas_tree:']
    response << 25.times { response << christmas_emojis.sample }
    response
  end

  def finish(text)
    date = begin
             Date.parse(text.split[1]).iso8601
           rescue StandardError
             return 'invalid date format'
           end

    return 'no advent of code puzzle on this date!' unless VALID_DATE_STRINGS.include?(date)

    return 'date already completed' if self.Finished.include?(date)

    self.Finished << date
    save

    "#{date} marked as finished"
  end

  def reset
    self.Finished = []
    save
  end

  def help
    'usage: /adventbot [reset|help|finish 2015-12-09]'
  end

  private

  def christmas_character
    characters = %w[santa mother_christmas]
    skin_tones = [2, 3, 4, 5, 6]
    ":#{characters.sample}::skin-tone-#{skin_tones.sample}:"
  end

end

def lambda_handler(event:, context:)
  response = {}

  slackorg = AdventBot.find(SlackOrg: event['team_domain'])
  unless slackorg
    slackorg = AdventBot.new
    slackorg.SlackOrg = event['team_domain']
    slackorg.Finished = []
    slackorg.save
  end

  response['text'] = case event['text']
                     when 'reset'
                       slackorg.reset
                     when 'help'
                       slackorg.help
                     when /^finish/
                       slackorg.finish(event['text'])
                     when 'status'
                       slackorg.status
                     else
                       slackorg.random
                     end

  response
end
