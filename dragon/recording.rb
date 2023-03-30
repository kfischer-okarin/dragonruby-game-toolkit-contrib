# coding: utf-8
# Copyright 2019 DragonRuby LLC
# MIT License
# recording.rb has been released under MIT (*only this file*).

module GTK
  # FIXME: Gross
  # @gtk
  class Replay
    # @gtk
    def self.start file_name = nil, speed: 1
      $recording.start_replay file_name, speed: speed
    end

    # @gtk
    def self.stop
      $recording.stop_replay
    end
  end

  # @gtk
  class Recording
    def initialize runtime
      @runtime = runtime
      @global_input_order = 1
    end

    def tick
      if @replay_next_tick && !is_replaying?
        @replay_next_tick = nil
        start_replay @replay_next_tick_file_name, speed: @replay_next_tick_simulation_speed
        @replay_next_tick_simulation_speed = nil
      end

      if is_replaying? && @on_replay_tick
        @on_replay_tick.call $gtk.args
      end

      if is_recording? && @on_recording_tick
        @on_recording_tick.call $gtk.args
      end
    end

    def on_replay_tick &block
      @on_replay_tick = block
    end

    def on_recording_tick &block
      @on_recording_tick = block
    end

    def start_recording seed_number = nil
      if !seed_number
        log <<-S
* ERROR:
To start recording, you must provide an integer value to
seed random number generation.
S
        $console.set_command "$recording.start SEED_NUMBER"
        return
      end

      if @is_recording
        log <<-S
* ERROR:
You are already recording, first cancel (or stop) the current recording.
S
        $console.set_command "$recording.cancel"
        return
      end

      if @is_replaying
        log <<-S
* ERROR:
You are currently replaying a recording, first stop the replay.
S
        return
      end

      log_info <<-S
Recording has begun with RNG seed value set to #{seed_number}.
To stop recording use stop_recording(filename).
The recording will stop without saving a file if a filename is nil.
S
      $console.set_command "$recording.stop 'replay.txt'"
      @is_recording = true
      @runtime.__reset__
      @seed_number = seed_number
      @runtime.set_rng seed_number

      @global_input_order = 1
      @input_history = []
      @runtime.notify! "Recording started. When completed, open the console to save it using $recording.stop FILE_NAME (or cancel).", 300
    end

    # @gtk
    def start seed_number = nil
      start_recording seed_number
    end

    def is_replaying?
      @is_replaying
    end

    def is_recording?
      @is_recording
    end

    # @gtk
    def stop file_name = nil
      stop_recording file_name
    end

    # @gtk
    def cancel
      stop_recording_core
      @runtime.notify! "Recording cancelled."
    end

    def stop_recording file_name = nil
      if !file_name
        log <<-S
* ERROR:
To please specify a file name when calling:
$recording.stop FILE_NAME

If you do NOT want to save the recording, call:
$recording.cancel
S
        $console.set_command "$recording.stop 'replay.txt'"
        return
      end

      if !@is_recording
        log_info "You are not currently recording. Use start_recording(seed_number) to start recording."
        $console.set_command "$recording.start"
        return
      end

      if file_name
        text = "replay_version 2.0\n"
        text << "stopped_at #{Kernel.tick_count}\n"
        text << "seed #{@seed_number}\n"
        text << "recorded_at #{Time.now.to_s}\n"
        @input_history.each do |items|
          text << "#{items}\n"
        end
        @runtime.write_file file_name, text
        @runtime.write_file 'last_replay.txt', text
        log_info "The recording has been saved successfully at #{file_name}. You can use start_replay(\"#{file_name}\") to replay the recording."
      end

      $console.set_command "$replay.start '#{file_name}', speed: 1"
      stop_recording_core
      @runtime.notify! "Recording saved to #{file_name}. To replay it: ~$replay.start \"#{file_name}\", speed: 1~."
      log_info "You can run the replay later on startup using: ./dragonruby mygame --replay #{@replay_file_name}"
      @recording_stopped_at = Kernel.global_tick_count
      nil
    end

    def recording_recently_completed?
      return false if !@recording_stopped_at
      (Kernel.global_tick_count - @recording_stopped_at) <= 5
    end

    def on_replay_completed_successfully &block
      @replay_completed_successfully_block = block
    end

    def stop_recording_core
      @is_recording = false
      @input_history = nil
      @last_history = nil
      @runtime.__reset__
    end

    def replay_completed_successfully?
      @replay_completed_successfully
    end

    def start_replay file_name = nil, speed: 1
      return if replay_recently_stopped?
      @replay_completed_successfully = false
      if !file_name
        log <<-S
* ERROR:
Please provide a file name to $recording.start.
S
        $console.set_command_silent "$replay.start 'replay.txt', speed: 1"
        return
      end

      text = @runtime.read_file file_name
      return false unless text

      if text.each_line.first.strip != "replay_version 2.0"
        raise "The replay file #{file_name} is not compatible with this version of DragonRuby Game Toolkit. Please recreate the replay (sorry)."
      end

      @replay_started_at = Kernel.global_tick_count
      @replay_file_name = file_name

      $replay_data = {
        input_history: { },
        stopped_at_current_tick: 0
      }

      text.each_line do |l|
        if l.strip.length == 0
          next
        elsif l.start_with? 'replay_version'
          next
        elsif l.start_with? 'seed'
          $replay_data[:seed] = l.split(' ').last.to_i
        elsif l.start_with? 'stopped_at'
          $replay_data[:stopped_at] = l.split(' ').last.to_i
        elsif l.start_with? 'recorded_at'
          $replay_data[:recorded_at] = l.split(' ')[1..-1].join(' ')
        elsif l.start_with? '['
          name, value_1, value_2, value_count, id, tick_count = l.strip.gsub('[', '').gsub(']', '').split(',')
          $replay_data[:input_history][tick_count.to_i] ||= []
          $replay_data[:input_history][tick_count.to_i] << {
            id: id.to_i,
            name: name.gsub(':', '').to_sym,
            value_1: value_1.to_f,
            value_2: value_2.to_f,
            value_count: value_count.to_i
          }
        else
          raise "Replay data seems corrupt. I don't know how to parse #{l}."
        end
      end

      $replay_data[:input_history].keys.each do |key|
        $replay_data[:input_history][key] = $replay_data[:input_history][key].sort_by {|input| input[:id]}
      end

      @runtime.__reset__
      @runtime.set_rng $replay_data[:seed]
      @is_replaying = true
      if speed
        speed = speed.clamp(1, 7)
        @runtime.simulation_speed = speed
      end
      log_info "Replay started =#{@replay_file_name}= speed: #{@runtime.simulation_speed}. (#{Kernel.global_tick_count})"
      @runtime.notify! "Replay started =#{@replay_file_name}= speed: #{@runtime.simulation_speed}."
    end

    def replay_next_tick file_name, speed: 1
      @replay_next_tick = true
      @replay_next_tick_file_name = file_name
      if speed
        speed = speed.clamp(1, 7)
        @replay_next_tick_simulation_speed = speed
      end
    end

    def replay_completed_at
      @replay_completed_at
    end

    def replay_stopped_at
      @replay_stopped_at
    end

    def replay_recently_started?
      return false if !@replay_started_at
      (Kernel.global_tick_count - @replay_started_at) <= 5
    end

    def replay_recently_stopped?
      return false if !@replay_stopped_at
      (Kernel.global_tick_count - @replay_stopped_at) <= 5
    end

    def replay_recently_completed?
      return false if !@replay_completed_at
      (Kernel.global_tick_count - @replay_completed_at) <= 5
    end

    def clear_replay_stopped_at!
      @replay_stopped_at = nil
    end

    def stop_replay notification_message = "Replay has been stopped."
      @runtime.simulation_speed = 1
      if !is_replaying?
        log <<-S
* ERROR:
No replay is currently running. Call ~$replay.start FILE_NAME, speed: 1~ to start a replay.
S

        $console.set_command "$replay.start 'replay.txt', speed: 1"
        return
      end
      log_info "#{notification_message} (#{Kernel.global_tick_count})"
      $replay_data = nil
      @global_input_order = 1
      @replay_stopped_at = Kernel.global_tick_count
      $console.set_command_silent "$replay.start '#{@replay_file_name}', speed: 1"
      @is_replaying = false
      @runtime.__reset__
      @runtime.notify! notification_message
    end

    def record_input_history name, value_1, value_2, value_count, clear_cache = false
      return if @is_replaying
      return unless @is_recording
      @input_history << [name, value_1, value_2, value_count, @global_input_order, Kernel.tick_count]
      @global_input_order += 1
    end

    def tick_replay
      if @on_replay_tick
        @on_replay_tick.call @runtime.args
      end
      stage_replay_values
    end

    def stage_replay_values
      return unless @is_replaying
      return unless $replay_data

      if ($replay_data[:stopped_at] - $replay_data[:stopped_at_current_tick]) <= 1
        @replay_completed_successfully = true
        if @replay_completed_successfully_block
          @replay_completed_successfully_block.call @runtime.args
        end
        @replay_completed_at = Kernel.global_tick_count
        stop_replay "Replay completed [#{@replay_file_name}]. To rerun, bring up the Console and press enter."
        @runtime.simulation_speed = 1
        return
      end

      inputs_this_tick = $replay_data[:input_history][$replay_data[:stopped_at_current_tick]]

      $replay_data[:stopped_at_current_tick] += 1

      if Kernel.global_tick_count.zmod?(60 * @runtime.simulation_speed)
        calculated_tick_count = ($replay_data[:stopped_at] + @replay_started_at) - Kernel.global_tick_count
        log_info "Replay ends in #{calculated_tick_count.idiv(60 * @runtime.simulation_speed)} second(s). (#{Kernel.global_tick_count})"
      end

      return unless inputs_this_tick
      inputs_this_tick.each do |v|
        args = []
        args << v[:value_1] if v[:value_count] >= 1
        args << v[:value_2] if v[:value_count] >= 2
        args << :replay
        $gtk.send v[:name], *args
      end
    end
  end
end
