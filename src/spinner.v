module pending

import time

// see [new_spinner](#new_spinner), [SpinnerConfig](#SpinnerConfig), [SpinnerState](#SpinnerState)
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
	// newline separated strings printed ABOVE the spinner
	line_above []string
	// newline separated strings printed BELOW the spinner
	line_below []string
	// string printed BEFORE the spinner in the same line
	prefix string
	// string printed AFTER the spinner in the same line
	suffix string
	// whether the spinner is paused
	// paused spinner won't print anything
	paused bool
	// whether the spinner is stopped
	// stopped spinner is unusable and can't be _restarted_
	stopped bool
}

// clone clones this spinner state
pub fn (s SpinnerState) clone() SpinnerState {
	return SpinnerState{
		...s
	}
}

pub type SpinnerFrames = []rune | []string

// you can get some cool spinners [here](https://github.com/sindresorhus/cli-spinners/blob/main/spinners.json)
[params]
pub struct SpinnerConfig {
	frames   SpinnerFrames [required]
	interval time.Duration [required]
	// used to map (read: modify) the frame before it gets printed
	// by default it will print the frame as-is
	map_frame     fn (frame string) string = default_map_frame
	initial_state SpinnerState
}

fn default_map_frame(frame string) string {
	return frame
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
	ch := chan SpinnerMessage{cap: 64}
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
				if state.stopped {
					break
				} else if state.paused {
					time.sleep(c.interval)
					continue
				}

				frame := c.map_frame(match c.frames {
					[]rune { c.frames[i % c.frames.len].str() }
					[]string { c.frames[i % c.frames.len] }
				})

				mut lines := []string{cap: 1 + state.line_above.len + state.line_below.len}
				lines << state.line_above
				lines << rlock state {
					'${state.prefix}${frame}${state.suffix}'
				}
				lines << state.line_below
				eprintln(lines.join_lines())

				time.sleep(c.interval)

				// term.clear_previous_line() for stderr
				eprint('\r\x1b[1A\x1b[2K'.repeat(lines.len))
				flush_stderr()
				i += 1
			}
		}
	}
}

// get_state returns (a clone of) the current spinner state
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
		// wait until the spinner actually stops
		s.handle.wait()
		// close the channel
		s.ch.close()
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
	rlock s.state {
		// don't do anything if the spinner already stopped
		if s.state.stopped {
			return false
		}
	}

	return lock s.state {
		cb(mut s.state)
		true
	}
}
