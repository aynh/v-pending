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
	defer {
		spinner.stop()
	}

	for i := 1; i <= 100; i += 1 {
		spinner.eprintln('${i:03} * 5 = ${i * 5:03}')
		time.sleep(40 * time.millisecond)
	}
}
