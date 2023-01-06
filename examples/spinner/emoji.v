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

	spinner := new_spinner(
		frames: [`🚶`, `🏃`]
		interval: 140 * time.millisecond
	)
	spinner.set_suffix(' running from problems..')

	time.sleep(5 * time.second)
	spinner.stop()
}
