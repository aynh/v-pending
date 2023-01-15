module main

import math
import pending { new_spinner }
import os
import time

fn main() {
	println(@FILE.all_after(os.wd_at_startup))

	spinner := new_spinner(frames: '⢄⢂⢁⡁⡈⡐⡠'.runes(), interval: 80 * time.millisecond)
	defer {
		spinner.stop()
	}

	for i := 1; i <= 100; i += 1 {
		spinner.eprintln('${i:03} ** 2 = ${math.powi(i, 2):05}')
		time.sleep(80 * time.millisecond)
	}
}
