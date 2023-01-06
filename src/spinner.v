module pending

import time

[noinit]
pub struct Spinner {
	// the state of this Spinner
	state shared SpinnerState
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

// new_spinner creates a Spinner instance
pub fn new_spinner(config SpinnerConfig) Spinner {
	shared state := SpinnerState{
		...config.initial_state
	}

	return Spinner{
		config: config
		state: state
		handle: spawn config.start(shared state)
	}
}

fn (c SpinnerConfig) start(shared state SpinnerState) {
	for i := 0; !state.stopped; {
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

		// term.clear_previous_line() for stderr
		eprint('\r\x1b[1A\x1b[2K')
		flush_stderr()

		i += 1
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
