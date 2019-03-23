## frozen_string_literal: true
# cd code; bundle install --without development test --path vendor/bundle; zip -r ../advent-bot.zip function.rb vendor) && aws lambda update-function-code --function-name advent-bot --zip-file fileb://advent-bot.zip
require 'date'
require 'json'
require 'aws-record'

require 'net/http'
require 'uri'
require 'cgi'

VALID_DATES = (Date.new(2015, 12, 1)..Date.today).select { |d| d.month == 12 && d.day < 26 }
VALID_DATE_STRINGS = VALID_DATES.map(&:iso8601)

class AdventBot
  include Aws::Record
  set_table_name ENV['DynamoDBTable']

  client_opts = {}
  client_opts['endpoint'] = 'http://host.docker.internal:8000' if ENV['AWS_SAM_LOCAL'] == 'true'
  configure_client client_opts

  string_attr :SlackOrg, hash_key: true
  string_attr :TeamName
  list_attr   :Finished

  def random
    dates_left = VALID_DATE_STRINGS - self.Finished
    return ':star: all problems completed :star:' if dates_left.length.zero?

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
    'usage: /adventbot [reset|status|help|finish 2015-12-09]'
  end

  private

  def christmas_character
    characters = %w[santa mother_christmas]
    skin_tones = [2, 3, 4, 5, 6]
    ":#{characters.sample}::skin-tone-#{skin_tones.sample}:"
  end
end

def lambda_handler(event:, context:)
  response = {
    'headers' => {}
  }

  if event['path'] == '/oauth'
    code = event.fetch('queryStringParameters', {})&.fetch('code', nil)
    unless code
      response['body'] = 'invalid code'
      response['statusCode'] = 400
      return response
    end

    uri = URI.parse("https://slack.com/api/oauth.access?code=#{code}&client_id=#{ENV['CLIENT_ID']}&client_secret=#{ENV['CLIENT_SECRET']}&redirect_uri=#{ENV['REDIRECT_URI']}")
    slack_res = JSON.parse(Net::HTTP.get_response(uri).body)
    unless slack_res['ok']
      response['body'] = 'invalid code'
      response['statusCode'] = 400
      return response
    end

    slackorg = AdventBot.find(SlackOrg: slack_res['team_id'])
    if slackorg
      response['body'] = 'org already exists'
      response['statusCode'] = 400
      return response
    end

    slackorg = AdventBot.new
    slackorg.SlackOrg = slack_res['team_id']
    slackorg.TeamName = slack_res['team_name']
    slackorg.Finished = []
    slackorg.save

    response['body'] = 'subscribed, buddy!'
    response['statusCode'] = 302
    response['headers']['Location'] = 'https://adventbot.com'
    response
  else
    team_id = CGI.parse(event['body'])['team_id'].first
    unless team_id
      response['body'] = 'invalid slack team_id'
      response['statusCode'] = 400
      return response
    end

    slackorg = AdventBot.find(SlackOrg: team_id)
    unless slackorg
      response['body'] = 'unknown slack team_id. add the slack org at adventbot.com'
      response['statusCode'] = 401
      return response
    end

    event = CGI.parse(event['body'])['text'].first
    response['body'] = case event
                       when 'reset'
                         slackorg.reset
                       when 'help'
                         slackorg.help
                       when /^finish/
                         slackorg.finish(event)
                       when 'status'
                         slackorg.status
                       else
                         slackorg.random
                       end

    response
  end
end

