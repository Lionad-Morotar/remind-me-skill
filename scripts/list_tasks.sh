#!/bin/bash
# 列出所有在途的提醒任务

config_dir="$HOME/.config/remind-me-skill"
tasks_dir="$config_dir/tasks"

[ -d "$tasks_dir" ] || { echo "没有在途任务"; exit 0; }

count=0
for task_file in "$tasks_dir"/*.task; do
  [ -f "$task_file" ] || continue
  
  title=$(grep "^TITLE=" "$task_file" | cut -d= -f2-)
  message=$(grep "^MESSAGE=" "$task_file" | cut -d= -f2-)
  target_at=$(grep "^TARGET_AT=" "$task_file" | cut -d= -f2)
  pid=$(grep "^PID=" "$task_file" | cut -d= -f2)
  
  target_time=$(date -r "$target_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "@$target_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
  
  echo "[$((++count))] $title"
  echo "    时间: $target_time"
  echo "    内容: $message"
  echo "    PID: $pid"
  echo ""
done

[ "$count" -eq 0 ] && echo "没有在途任务"
