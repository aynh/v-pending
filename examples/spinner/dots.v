module main

import pending { new_spinner }
import os
import term
import time

fn main() {
	println(@FILE.all_after(os.wd_at_startup))
	defer {
		term.clear_previous_line()
	}

	spinner := new_spinner(frames: '⢄⢂⢁⡁⡈⡐⡠'.runes(), interval: 80 * time.millisecond)
	time.sleep(5 * time.second)
	spinner.stop()
}
