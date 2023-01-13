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
mut:
	prefix  string
	suffix  string
	paused  bool
	stopped bool
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
	for i := 0; true; {
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

				rlock state {
					eprintln('${state.prefix}${frame}${state.suffix}')
				}

				time.sleep(c.interval)

				if !state.stopped {
					// term.clear_previous_line() for stderr
					eprint('\r\x1b[1A\x1b[2K')
					flush_stderr()
				} else {
					break
				}

				i += 1
			}
		}
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

// mutate_state calls cb on the SpinnerState only if the spinner is not stoppep
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
