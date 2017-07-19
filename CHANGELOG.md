# OWASP Scripts

* * *

## 0.0.1

-   Ruby script for updating OWASP thresholds
-   update-thresholds.rb

    -   This script will pull the OWASP object for a service and capture it's id and the current threshold values for the following categories:
            \- http_violation_score_threshold
            \- inbound_anomaly_score_threshold
            \- lfi_score_threshold
            \- php_injection_score_threshold
            \- rce_score_threshold
            \- rfi_score_threshold
            \- session_fixation_score_threshold
            \- sql_injection_score_threshold
            \- xss_score_threshold

        A user will then be able to increase or decrease all scores by a value. Lastly the changes will be pushed by a patch to the ruleset.
