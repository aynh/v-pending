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
		interval: 80 * time.millisecond
		initial_state: pending.SpinnerState{
			prefix: 'A:'
			suffix: ':B'
		}
		map_frame: fn (frame string) string {
			return term.black(term.bg_rgb(255, 192, 203, frame))
		}
		frames: [
			'▐⠂       ▌',
			'▐⠈       ▌',
			'▐ ⠂      ▌',
			'▐ ⠠      ▌',
			'▐  ⡀     ▌',
			'▐  ⠠     ▌',
			'▐   ⠂    ▌',
			'▐   ⠈    ▌',
			'▐    ⠂   ▌',
			'▐    ⠠   ▌',
			'▐     ⡀  ▌',
			'▐     ⠠  ▌',
			'▐      ⠂ ▌',
			'▐      ⠈ ▌',
			'▐       ⠂▌',
			'▐       ⠠▌',
			'▐       ⡀▌',
			'▐      ⠠ ▌',
			'▐      ⠂ ▌',
			'▐     ⠈  ▌',
			'▐     ⠂  ▌',
			'▐    ⠠   ▌',
			'▐    ⡀   ▌',
			'▐   ⠠    ▌',
			'▐   ⠂    ▌',
			'▐  ⠈     ▌',
			'▐  ⠂     ▌',
			'▐ ⠠      ▌',
			'▐ ⡀      ▌',
			'▐⠠       ▌',
		]
	)

	time.sleep(5 * time.second)
	spinner.stop()
}
