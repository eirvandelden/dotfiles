#!/bin/bash
input=$(cat)

transcript_path=$(echo "$input" | grep -o '"transcript_path":"[^"]*"' | head -1 | sed 's/"transcript_path":"//;s/"$//')

last_message_time=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  last_message_line=$(grep '"type":"assistant"' "$transcript_path" | tail -1)
  last_message_iso=$(echo "$last_message_line" | grep -o '"timestamp":"[^"]*"' | head -1 | sed 's/"timestamp":"//;s/"$//;s/\.[0-9]*Z$//')

  if [ -n "$last_message_iso" ]; then
    last_message_epoch=$(date -ju -f "%Y-%m-%dT%H:%M:%S" "$last_message_iso" "+%s" 2>/dev/null)
    [ -n "$last_message_epoch" ] && last_message_time=$(date -r "$last_message_epoch" "+%H:%M" 2>/dev/null)
  fi
fi

pr_block=$(echo "$input" | grep -o '"pr":{[^}]*}')
pr_url=$(echo "$pr_block" | grep -o '"url":"[^"]*"' | head -1 | sed 's/"url":"//;s/"$//')

line=""
[ -n "$last_message_time" ] && line="Last reply: $last_message_time"
if [ -n "$pr_url" ]; then
  [ -n "$line" ] && line="$line | $pr_url" || line="$pr_url"
fi

[ -n "$line" ] && echo "$line"
