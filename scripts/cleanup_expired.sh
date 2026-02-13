#!/bin/bash
# 清理过期的提醒任务

config_dir="$HOME/.config/remind-me-skill"
tasks_dir="$config_dir/tasks"

[ -d "$tasks_dir" ] || exit 0

now=$(date +%s)
expired_count=0

for task_file in "$tasks_dir"/*.task; do
  [ -f "$task_file" ] || continue
  
  target_at=$(grep "^TARGET_AT=" "$task_file" 2>/dev/null | cut -d= -f2)
  [ -z "$target_at" ] && continue
  
  if [ "$target_at" -lt "$now" ]; then
    title=$(grep "^TITLE=" "$task_file" | cut -d= -f2-)
    message=$(grep "^MESSAGE=" "$task_file" | cut -d= -f2-)
    
    # 显示过期提醒
    osascript -e "display notification \"$message\" with title \"[已过期] $title\"" 2>/dev/null || true
    
    # 删除任务文件
    rm -f "$task_file"
    ((expired_count++))
  fi
done

[ "$expired_count" -gt 0 ] && echo "清理了 $expired_count 个过期任务"
