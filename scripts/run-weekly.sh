#!/bin/bash
# 주간 요약만 따로 돌릴 때. 내부적으로 run-daily.sh weekly 로 위임한다.
exec bash "$(dirname "$0")/run-daily.sh" weekly
