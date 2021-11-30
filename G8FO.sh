 
 ​#!​/usr/bin/env bash 

 UINT_MAX="4294967295"
 
 ​BRANCH=​"​main"

 ​SCHED_PERIOD=​"​$((​1​ ​*​ ​1000​ ​*​ ​1000​))​" 
 
 ​SCHED_TASKS=​"​10​" 
  
 ​write​() { 
 ​        ​#​ Bail out if file does not exist 
 ​        [[ ​!​ ​-f​ ​"​$1​"​ ]] ​&&​ ​return​ 1 
  
 ​        ​#​ Make file writable in case it is not already 
 ​        chmod +w ​"​$1​"​ ​2>​ /dev/null 
  
 ​        ​#​ Write the new value and bail if there's an error 
 ​        ​if​ ​!​ ​echo​ ​"​$2​"​ ​>​ ​"​$1​"​ ​2>​ /dev/null 
 ​        ​then 
 ​                ​echo​ ​"​Failed: ​$1​ → ​$2​" 
 ​                ​return​ 1 
 ​         fi
        
 ​       echo​ ​"​$1​ → ​$2​" 
 ​} 
  
 ​#​ Root check 
 ​if​ [[ ​"​$(​id -u​)​"​ ​-ne​ 0 ]] 
 ​then 
 ​        ​echo​ ​"​No root permissions. Exiting.​" 
 ​        ​exit​ 1 
 ​fi 

 ​grep -q android /proc/cmdline ​&&​ ANDROID=true 
  
 ​#​ Log the date for some sht
 ​echo​ ​"​Time of execution: ​$(​date​)​" 
 ​echo​ ​"​Branch: ​$BRANCH​" 

 ​write /proc/sys/kernel/perf_cpu_time_max_percent 3 
  
 ​#​ Task autogroup
 ​write /proc/sys/kernel/sched_autogroup_enabled 1 
 ​write /proc/sys/kernel/sched_child_runs_first 1 
 ​write /proc/sys/kernel/sched_tunable_scaling 0 
 ​write /proc/sys/kernel/sched_latency_ns ​"​$SCHED_PERIOD​" 
 ​write /proc/sys/kernel/sched_min_granularity_ns ​"​$((​SCHED_PERIOD ​/​ SCHED_TASKS​))​" 
 ​write /proc/sys/kernel/sched_wakeup_granularity_ns ​"​$((​SCHED_PERIOD ​/​ ​2​))"
 ​write /proc/sys/kernel/sched_migration_cost_ns 5000000 
  
 ​#​ Always allow sboost
 ​[[ ​"​$ANDROID​"​ ​==​ ​true​ ]] ​&&​ write /proc/sys/kernel/sched_min_task_util_for_colocation 0 
  
 ​#​ Reducing the scheduler migration time and some stuff 
 ​write /proc/sys/kernel/sched_nr_migrate 4 
 ​write /proc/sys/kernel/sched_schedstats 0  
 ​write /proc/sys/kernel/printk_devkmsg ofof 
 ​write /proc/sys/vm/dirty_background_ratio 3 
  
 ​#​ Vm 
 ​write /proc/sys/vm/dirty_ratio 30 
 ​write /proc/sys/vm/dirty_expire_centisecs 3000 
 ​write /proc/sys/vm/dirty_writeback_centisecs 3000 
 ​write /proc/sys/vm/page-cluster 0 
  
 ​#​ Reduce jitter 
 ​write /proc/sys/vm/stat_interval 10 
  
 ​#​ Swap
 ​write /proc/sys/vm/swappiness 100 
 ​write /proc/sys/vm/vfs_cache_pressure 200 
  
 ​#​ ECC
 ​write /proc/sys/net/ipv4/tcp_ecn 1 
 ​write /proc/sys/net/ipv4/tcp_fastopen 3 
 ​write /proc/sys/net/ipv4/tcp_syncookies 0 
  
 ​if​ [[ ​-f​ ​"​/sys/kernel/debug/sched_features​"​ ]] 
 ​then
 ​        write /sys/kernel/debug/sched_features NEXT_BUDDY 
 ​        write /sys/kernel/debug/sched_features NO_TTWU_QUEUE 
 ​fi 
  
 ​[[ ​"​$ANDROID​"​ ​==​ ​true​ ]] ​&&​ ​if​ [[ ​-d​ ​"​/dev/stune/​"​ ]] 
 ​then 
 ​        ​#​ Prefer to schedule top-app tasks on idle CPUs 
 ​        write /dev/stune/top-app/schedtune.prefer_idle 1 
  
 ​        ​#​ Mark top-app as boosted for perf CPU
 ​        write /dev/stune/top-app/schedtune.boost 1 
 ​fi 
   
 ​for​ ​cpu​ ​in​ /sys/devices/system/cpu/cpu​*​/cpufreq 
 ​do
 ​        avail_govs=​"​$(​cat ​"​$cpu​/scaling_available_governors​"​)​" 
 ​        ​for​ ​governor​ ​in​ schedutil interactive 
 ​        ​do 
 ​                ​#​ Once a matching governor is found, set it and break for this CPU 
 ​                ​if​ [[ ​"​$avail_govs​"​ ​==​ ​*​"​$governor​"​*​ ]] 
 ​                ​then 
 ​                        write ​"​$cpu​/scaling_governor​"​ ​"​$governor​" 
 ​                        ​break 
 ​                ​fi 
 ​        ​done 
 ​done 
  
 ​#​ Schedutil tune
 ​find /sys/devices/system/cpu/ -name schedutil -type d ​|​ ​while​ IFS= ​read​ -r governor 
 ​do
 ​        write ​"​$governor​/up_rate_limit_us​"​ 0 
 ​        write ​"​$governor​/down_rate_limit_us​"​ 0 
 ​        write ​"​$governor​/rate_limit_us​"​ 0 
  
 ​        ​#​ Load percentage 
 ​        write ​"​$governor​/hispeed_load​"​ 85 
 ​        write ​"​$governor​/hispeed_freq​"​ ​"​$UINT_MAX​" 
 ​done 
  
 ​#​ Interactive 
 ​find /sys/devices/system/cpu/ -name interactive -type d ​|​ ​while​ IFS= ​read​ -r governor 
 ​do 
 ​        write ​"​$governor​/timer_rate​"​ 0 
 ​        write ​"​$governor​/min_sample_time​"​ 0
 ​        write ​"​$governor​/go_hispeed_load​"​ 85 
 ​        write ​"​$governor​/hispeed_freq​"​ ​"​$UINT_MAX​" 
 ​done 
  
 ​for​ ​queue​ ​in​ /sys/block/​*​/queue 
 ​do 
 ​        ​#​ IO tweak
 ​        avail_scheds=​"​$(​cat ​"​$queue​/scheduler​"​)​" 
 ​        ​for​ ​sched​ ​in​ cfq noop kyber bfq mq-deadline none 
 ​        ​do 
 ​                ​if​ [[ ​"​$avail_scheds​"​ ​==​ ​*​"​$sched​"​*​ ]] 
 ​                ​then 
 ​                        write ​"​$queue​/scheduler​"​ ​"​$sched​" 
 ​                        ​break 
 ​                ​fi 
 ​        ​done
 ​        write ​"​$queue​/add_random​"​ 0 
 ​        write ​"​$queue​/iostats​"​ 0 
 ​        write ​"​$queue​/read_ahead_kb​"​ 32
 ​        write ​"​$queue​/nr_requests​"​ 32 
 ​done 
  
 ​#​ Always return success, even if the last write fails 
 ​exit​ 0
