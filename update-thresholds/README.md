# Update Thresholds

This script updates the OWASP thresholds. By default, it will increment the current values by 30.

### Requirements

-   Ruby >= 2.4.1

### Setup

Run `bundle install`

### Usage

    USAGE: update-thresholds.rb [options]
        -h, --help                       Help Menu
        -a, --api-token TOKEN            Fastly api-token
        -s, --service-id ID              service ID

To execute:

    bundle exec ruby update-threshold.rb -a API-Token -s Service_ID
