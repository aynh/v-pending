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
	for i := 0; i <= 100; i += 1 {
		spinner.set_suffix(' 1st line: ${i:03}')
		spinner.set_line_below([
			'2nd line : ${i:03} * 2 is ${i * 2:03}',
			'3rd line : ${i:03} * 3 is ${i * 3:03}',
			'4th line : ${i:03} * 4 is ${i * 4:03}',
			'5th line : ${i:03} * 5 is ${i * 5:03}',
		])
		time.sleep(rand.intn(100)! * time.millisecond)
	}
}
