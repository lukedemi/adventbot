# Advent Bot

Advent Bot is a simple Slack Slash Command that returns a random Advent of Code problem.

<a href="https://slack.com/oauth/authorize?client_id=12291972454.522961948981&scope=commands"><img alt="Add to Slack" height="40" width="139" src="https://platform.slack-edge.com/img/add_to_slack.png" srcset="https://platform.slack-edge.com/img/add_to_slack.png 1x, https://platform.slack-edge.com/img/add_to_slack@2x.png 2x" /></a>

## Why?

Last holiday season, a few co-workers and I spent an hour or two (or 24) every night racing against the clock to solve that night's Advent of Code problem. If you haven't heard of [Advent of Code](https://adventofcode.com/), it's an amazing Advent Calendar of small (sometimes not so small) programing problems.

After completing 2018, we felt a bit of an emptiness - we wanted a way to continue the holiday Advent of Code cheer thoughout the year. Ideally, we wanted to be able to summon a random Advent of Code problem any day of the year.

## Screenshots

### /adventbot random

<img src="./screenshots/random.png" alt="random" />

### /adventbot status

<img src="./screenshots/status.png" alt="status" />

## How it works

Add Advent Bot to a slack channel then simply call `/adventbot` any time you want to recieve a fresh Advent of Code challenge!

If you have already completed a year or two, call `/adventbot finish 2015-12-09` with any iso8601 compatible date.

At any time, call `/adventbot status` to see which problems you've already completed.

## Packaging and deployment

AdventBot uses AWS SAM for resource definition and deployment. Right now it's not doing any fancy local execution (you have to manually pass an event), but I'm hoping to tighten all this up as I learn more about AWS SAM.

```
(cd code; bundle install --without development test --path vendor/bundle)
sam package --template-file template.yaml --output-template-file packaged.yaml --s3-bucket adventbucket
aws cloudformation deploy --template-file ./packaged.yaml --stack-name AdventBot --capabilities CAPABILITY_IAM
```

## Local testing

```
# something like this
docker run -p 8000:8000 amazon/dynamodb-local
sam local invoke --event test_event.json
```

## Privacy Policy

Feel free to look at the code to see what this thing is actually doing, but the only things stored in the DynamoDB table are the slack team id, slack team name, and the puzzles you've completed. I will not do anything with this data (except maybe lose it at some point).
