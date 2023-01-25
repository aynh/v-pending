module pending

import time

fn new_test_spinner() Spinner {
	return new_spinner(
		frames: '⢄⢂⢁⡁⡈⡐⡠'.runes()
		interval: 80 * time.millisecond
	)
}

fn test_spinner_pause() {
	spinner := new_test_spinner()
	defer {
		spinner.stop()
	}

	rlock spinner.state {
		assert spinner.state.paused == false
	}

	start := time.now()
	spinner.pause()
	// pause should take atleast interval duration
	assert time.now() - start >= spinner.config.interval

	rlock spinner.state {
		assert spinner.state.paused == true
	}
}

fn test_spinner_start() {
	spinner := new_test_spinner()
	defer {
		spinner.stop()
	}

	spinner.pause()
	rlock spinner.state {
		assert spinner.state.paused == true
	}

	spinner.start()
	rlock spinner.state {
		assert spinner.state.paused == false
	}
}

fn test_spinner_stop() {
	spinner := new_test_spinner()
	assert spinner.ch.closed == false
	rlock spinner.state {
		assert spinner.state.stopped == false
	}

	start := time.now()
	spinner.stop()
	// stop should take atleast interval duration
	assert time.now() - start >= spinner.config.interval

	assert spinner.ch.closed == true
	rlock spinner.state {
		assert spinner.state.stopped == true
	}
}

fn test_spinner_eprintln_println() {
	spinner := new_test_spinner()
	defer {
		spinner.stop()
	}

	lock spinner.state {
		spinner.state.stopped = true
	}
	spinner.handle.wait()

	handle := spawn fn (ch chan SpinnerMessage) {
		one := <-ch
		assert one == SpinnerMessage{
			content: '1st'
			@type: .println
		}
		two := <-ch
		assert two == SpinnerMessage{
			content: '2nd'
			@type: .eprintln
		}
		three := <-ch
		assert three == SpinnerMessage{
			content: '3rd'
			@type: .println
		}
	}(spinner.ch)

	spinner.println('1st')
	spinner.eprintln('2nd')
	spinner.println('3rd')

	handle.wait()
}

fn test_spinner_setters() {
	spinner := new_test_spinner()
	defer {
		spinner.stop()
	}

	rlock spinner.state {
		assert spinner.state.line_above == []string{}
		assert spinner.state.line_below == []string{}
		assert spinner.state.prefix == ''
		assert spinner.state.suffix == ''
	}

	spinner.set_prefix('prefix')
	spinner.set_suffix('suffix')
	spinner.set_line_above(['1st line', ''])
	spinner.set_line_above_at(1, '2nd line')
	spinner.set_line_below(['1st line', '2nd line', 'last line'])
	spinner.set_line_below_at(-1, 'last line')
	rlock spinner.state {
		assert spinner.state.line_above == ['1st line', '2nd line']
		assert spinner.state.line_below == ['1st line', '2nd line', 'last line']
		assert spinner.state.prefix == 'prefix'
		assert spinner.state.suffix == 'suffix'
	}
}

fn test_spinner_mutate_state() {
	spinner := new_test_spinner()
	rlock spinner.state {
		assert spinner.state.prefix == ''
	}

	ret1 := spinner.mutate_state(fn (mut state SpinnerState) {
		state.prefix = 'modified'
	})
	// mutate_state return true if the function get called
	assert ret1 == true
	rlock spinner.state {
		assert spinner.state.prefix == 'modified'
	}

	spinner.stop()
	ret2 := spinner.mutate_state(fn (mut state SpinnerState) {
		state.prefix = 'modified again'
	})
	assert ret2 == false
	rlock spinner.state {
		assert spinner.state.prefix == 'modified'
	}
}
