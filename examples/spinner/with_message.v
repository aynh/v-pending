module main

import pending { new_spinner }
import os
import rand
import term
import time

fn main() {
	println(@FILE.all_after(os.wd_at_startup))
	defer {
		term.clear_previous_line()
	}

	spinner := new_spinner(
		frames: [`◜`, `◠`, `◝`, `◞`, `◡`, `◟`]
		interval: 100 * time.millisecond
	)

	defer {
		spinner.stop()
	}
	for i in 0 .. 100 {
		spinner.set_suffix(' fetching [${i}/100]')
		time.sleep((100 + rand.intn(100)!) * time.millisecond)
	}
}
