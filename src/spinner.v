module pending

import time

[noinit]
pub struct Spinner {
	// the state of this Spinner
	state shared SpinnerState
	// the channel to send and receive (e)println contents
	ch chan SpinnerMessage
	// the thread spawned when this Spinner is created
	handle thread
pub:
	// the config used to create this Spinner
	config SpinnerConfig
}

pub struct SpinnerState {
pub mut:
	line_above []string
	line_below []string
	prefix     string
	suffix     string
	paused     bool
	stopped    bool
}

pub fn (s SpinnerState) clone() SpinnerState {
	return SpinnerState{
		...s
	}
}

pub type SpinnerFrames = []rune | []string

[params]
pub struct SpinnerConfig {
	frames        SpinnerFrames [required]
	interval      time.Duration [required]
	initial_state SpinnerState
}

struct SpinnerMessage {
	content string
	@type   SpinnerMessageType = .println
}

enum SpinnerMessageType {
	println
	eprintln
}

// new_spinner creates a Spinner instance
pub fn new_spinner(config SpinnerConfig) Spinner {
	ch := chan SpinnerMessage{}
	shared state := SpinnerState{
		...config.initial_state
	}

	return Spinner{
		config: config
		ch: ch
		state: state
		handle: spawn config.start(shared state, ch)
	}
}

fn (c SpinnerConfig) start(shared state SpinnerState, ch chan SpinnerMessage) {
	for i := 0; !state.stopped; {
		select {
			message := <-ch {
				print_cb := match message.@type {
					.println { println }
					.eprintln { eprintln }
				}

				print_cb(message.content)
			}
			else {
				if state.paused {
					time.sleep(c.interval)
					continue
				}

				frame := match c.frames {
					[]rune { c.frames[i % c.frames.len].str() }
					[]string { c.frames[i % c.frames.len] }
				}

				mut lines_count := rlock state {
					mut lines := []string{cap: 1 + state.line_above.len + state.line_below.len}
					lines << state.line_above
					lines << '${state.prefix}${frame}${state.suffix}'
					lines << state.line_below

					eprintln(lines.join_lines())
					lines.len
				}

				time.sleep(c.interval)

				if state.stopped {
					lines_count -= 1
				}

				if lines_count > 0 {
					// term.clear_previous_line() for stderr
					eprint('\r\x1b[1A\x1b[2K'.repeat(lines_count))
					flush_stderr()
					i += 1
				}
			}
		}
	}
}

pub fn (s Spinner) get_state() SpinnerState {
	return rlock s.state {
		s.state.clone()
	}
}

// pause pauses the spinner
pub fn (s Spinner) pause() {
	if s.mutate_state(fn (mut state SpinnerState) {
		state.paused = true
	})
	{
		// wait until the spinner actually stops
		time.sleep(s.config.interval)
	}
}

// start starts the spinner
pub fn (s Spinner) start() {
	s.mutate_state(fn (mut state SpinnerState) {
		state.paused = false
	})
}

// stop stops the spinner
//
// the spinner is unusable after calling this
pub fn (s Spinner) stop() {
	if s.mutate_state(fn (mut state SpinnerState) {
		state.stopped = true
	})
	{
		// close the channel
		s.ch.close()
		// wait until the spinner actually stops
		s.handle.wait()
	}
}

// set_prefix sets the prefix of the Spinner
pub fn (s Spinner) set_prefix(ss string) {
	s.mutate_state(fn [ss] (mut state SpinnerState) {
		state.prefix = ss
	})
}

// set_suffix sets the suffix of the spinner
pub fn (s Spinner) set_suffix(ss string) {
	s.mutate_state(fn [ss] (mut state SpinnerState) {
		state.suffix = ss
	})
}

// println is a helper method to println above the spinner
pub fn (s Spinner) println(ss string) {
	if !s.ch.closed {
		s.ch <- SpinnerMessage{
			content: ss
			@type: .println
		}
	}
}

// eprintln is a helper method to eprintln above the spinner
pub fn (s Spinner) eprintln(ss string) {
	if !s.ch.closed {
		s.ch <- SpinnerMessage{
			content: ss
			@type: .eprintln
		}
	}
}

// set_line_above sets the line above the spinner
pub fn (s Spinner) set_line_above(ss []string) {
	s.mutate_state(fn [ss] (mut state SpinnerState) {
		state.line_above = ss
	})
}

// set_line_above_at sets the line above the spinner at specific index
pub fn (s Spinner) set_line_above_at(i int, ss string) {
	s.mutate_state(fn [i, ss] (mut state SpinnerState) {
		state.line_above[i] = ss
	})
}

// set_line_below sets the line below the spinner
pub fn (s Spinner) set_line_below(ss []string) {
	s.mutate_state(fn [ss] (mut state SpinnerState) {
		state.line_below = ss
	})
}

// set_line_below_at sets the line below the spinner at specific index
pub fn (s Spinner) set_line_below_at(i int, ss string) {
	s.mutate_state(fn [i, ss] (mut state SpinnerState) {
		state.line_below[i] = ss
	})
}

// mutate_state calls cb on the SpinnerState only if the spinner is not stopped
//
// it returns true if cb is called, and false otherwise
fn (s Spinner) mutate_state(cb fn (mut SpinnerState)) bool {
	lock s.state {
		// don't do anything if the spinner already stopped
		if s.state.stopped {
			return false
		}

		cb(mut s.state)
	}

	return true
}
