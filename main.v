module main

import term.ui as tui
import time
import os
import toml

const (
	start_path = os.abs_path('')
)

/*
ask about -prof and -prod for  term.ui
TODO :
+ scroll si trop de files / trop de chars dans l'input
+ help shortcuts like ? for ex
+ add/suppr with short cut Favorites files

. rename
.ù 
. lettre en majuscucules
. apparition dans un dossier choisi
. multiple file selection 
. Copier le path
. Copier le path de l'elem
. Tabs
. si ctrl + 1->9  jump au fichier dans x 
. access any parameter of config.toml in the tui (with interfaces)

- opti search -> multithreading ?
- copy name of elem
- title of the window
- config : colors
- zip
- config : choose your own border chars
- Launch programs (with extention name?) (avec truc comme l'autocomplétion sous la barre de recherche)
- favorite commands
- find a way to redraw only the modified things (will enable the full custom bg)
- clearer crash logs / no crashes of the app (but fails yeah)
- diff algo tri

? Protected files
? appui sur a->z / 0->9 emmène sur le prochain fichier contenant cette lettre
*/

struct App {
mut:
	tui &tui.Context = unsafe { nil }

	actual_path string = os.abs_path('')
	actual_i    int
	actual_scroll int
	dir_list    []string
	fav_folders []string
	frame_nb    int
	last_event  string
	fav_mode bool
	fav_index int
	edit_mode string
	question_mode string
	question_answer bool
	edit_text string
	refresh bool
	sort_name string = "Sorted by name"
	copy_path string
	cut_mode bool
	cmd_mode bool
	cmd_text string
	search_mode bool
	search_text string
	search_results []string
	search_i int = -1
	search_success bool
	search_time f64

	old_actual_path string
	old_actual_i    int
	old_edit_mode string
	old_edit_text string
	old_question_mode string
	old_question_answer bool
	old_fav_mode bool
	old_fav_index int
	old_cmd_mode bool
	old_cmd_text string
	old_search_mode bool
	old_search_text string
	old_search_i int

	chdir_error string

	associated_apps map[string]string 
	key_binds map[string]string 
	bg_color []u8
	folder_highlight []u8
	choice_highlight []u8
	folder_font []u8
	file_highlight []u8
	fav_highlight []u8
	search_highlight []u8
}

fn event(e &tui.Event, x voidptr) {
	mut app := unsafe { &App(x) }
	app.chdir_error = ''
	if e.typ == .key_down {
		if app.edit_mode != ""{
			match e.code {
				.null {}
				.escape {
					app.edit_mode = ""
					app.edit_text = ""
					app.last_event = "escape edit"
				}
				.backspace {
					if app.edit_text.len > 0{
						app.edit_text = app.edit_text[0..app.edit_text.len-1]
					}
				}
				.enter {
					if app.edit_mode == "Name of the new folder:" {
						os.mkdir(os.join_path_single(app.actual_path, app.edit_text)) or {er("mkdir $err")}
						app.update_dir_list()
						app.edit_text = ""
						app.edit_mode = ""
						app.last_event = "create folder escape edit"
					}else if app.edit_mode == "Name of the new file:" {
						mut f := os.create(os.join_path_single(app.actual_path, app.edit_text)) or {er("create file $err");os.File{}}
						f.close()
						app.update_dir_list()
						app.edit_text = ""
						app.edit_mode = ""
						app.last_event = "create file escape edit"
					}
				}
				else{
					app.edit_text += key_str(e.code)
				}
			}
		} else if app.question_mode != "" {			
			match e.code {
				.right {app.question_answer = !app.question_answer}
				.left {app.question_answer = !app.question_answer}
				.enter {
					if app.question_answer{
						if app.question_mode == "Delete this file ?" {
							os.rm(os.join_path_single(app.actual_path, app.dir_list[app.actual_i])) or {er('rm $err')}
							app.update_dir_list()
							if app.dir_list.len > 0{
								app.actual_i = app.actual_i % app.dir_list.len
							}
							app.last_event = "deleted a file"
						}else{
							if app.question_mode == "Delete this folder ?" {
								os.rmdir_all(os.join_path_single(app.actual_path, app.dir_list[app.actual_i])) or {er('rmdir_all $err')}
								app.update_dir_list()
								if app.dir_list.len > 0{
									app.actual_i = app.actual_i % app.dir_list.len
								}
								app.last_event = "deleted a folder"
							}
						}
					}
					app.refresh = true
					app.question_mode = ''
					app.question_answer = false
				}
				.escape {
					app.question_mode = ""
					app.question_answer = false
					app.last_event = "escape question"
				}
				else{}
			}
		} else if app.fav_mode{
			match e.code {
				.f {
					app.fav_index = 0
					app.fav_mode = false
				}
				.escape {
					app.fav_index = 0
					app.fav_mode = false
				}
				.up {
					if app.fav_folders != [] {
						app.fav_index = if (app.fav_index - 1) == -1 {
								app.fav_folders.len - 1
							} else {
								app.fav_index - 1
							}
					}
					app.last_event = 'fav up'
				}
				.down {
					if app.fav_folders != [] {
						app.fav_index = (app.fav_index + 1) % app.fav_folders.len
					}
					app.last_event = 'fav down'
				}
				.enter {
					app.actual_path = app.fav_folders[app.fav_index]
					app.fav_index = 0
					app.fav_mode = false
					os.chdir(app.actual_path) or {
						er('go in fav ${err}')
						app.chdir_error = '${err}'
					}
					app.update_dir_list()
					if app.dir_list.len > 0{
						app.actual_i = app.actual_i % app.dir_list.len
					}
				}
				else{}
			}
		} else if app.cmd_mode {
			match e.code {
				.escape {
					app.cmd_mode = false
				}
				.enter {
					spawn os.execute("start cmd /c" + app.cmd_text)
					er('ooo')
					app.cmd_mode = false
				}
				.backspace {
					if app.cmd_text.len > 0{
						app.cmd_text = app.cmd_text[0..app.cmd_text.len-1]
					}
				}
				else {app.cmd_text += key_str(e.code)}
			}
		} else if app.search_mode {
			match e.code {
				.escape {
					app.search_mode = false
					app.search_results = []
					app.search_success = false
					app.search_time = 0.0
				}
				.enter {
					if app.search_i == -1{
						sw := time.new_stopwatch()
						app.search_results = search(app.search_text, app.actual_path)
						app.search_time = sw.elapsed().seconds()
						app.search_success = true
						app.refresh = true
					}else{
						if os.is_dir(app.search_results[app.search_i]) {
							app.actual_path = app.search_results[app.search_i]
							os.chdir(app.actual_path) or {
								er('go to w/ search ${err}')
								app.chdir_error = '${err}'
							}
							app.search_mode = false
							app.search_results = []
							app.search_time = 0.0
							er("werk")
						} else {
							file_ext := os.file_ext(app.search_results[app.search_i])
							if file_ext in app.associated_apps{
								spawn os.execute('${app.associated_apps[file_ext]} \"${app.search_results[app.search_i]}\"')
							}else{
								spawn os.execute('${app.associated_apps["else"]} \"${app.search_results[app.search_i]}\"')
							}
						}
					}
				}
				.backspace {
					if app.search_text.len > 0{
						app.search_text = app.search_text[0..app.search_text.len-1]
					}
				}
				.up {
					if app.search_results != [] {
						app.search_i = if (app.search_i - 1) <= -1 {
							app.search_results.len - 1
						} else {
							app.search_i - 1
						}
					}
				}
				.down {
					if app.search_results != [] {
						app.search_i = (app.search_i + 1) % app.search_results.len
					}
				}
				else {app.search_text += key_str(e.code); app.search_i = -1}
			}
		} else {
			match e.code {
				.c  {
					if e.modifiers.has(.ctrl){
						app.copy_path = os.abs_path(app.dir_list[app.actual_i])
						app.refresh = true
						app.cut_mode = false
						app.last_event = 'copy'
					}else {
						app.cmd_mode = true
						app.cmd_text = ""
						app.last_event = 'cmd mode'
					}
				}
				.x  {
					if e.modifiers.has(.ctrl){
						app.copy_path = os.abs_path(app.dir_list[app.actual_i])
						app.refresh = true
						app.cut_mode = true
						app.last_event = 'cut'
					}
				}
				.v  {
					if e.modifiers.has(.ctrl){
						if app.cut_mode {
							os.mv(app.copy_path, app.actual_path+"\\"+os.file_name(app.copy_path)) or {er("cut paste file $err")}
						}else{
							if e.modifiers.has(.shift){
								os.cp_all(app.copy_path, app.actual_path+"\\"+os.file_name(app.copy_path), true) or {er("copy paste overwrite $err")}
							}else{
								if !os.is_dir(app.copy_path){
									os.cp(app.copy_path, app.actual_path+"\\"+os.file_name(app.copy_path)) or {er("copy paste file $err")}
								}else{
									os.cp_all(app.copy_path, app.actual_path+"\\"+os.file_name(app.copy_path), false) or {er("copy paste dir $err")}
								}
							}
						}
						app.update_dir_list()
						if app.dir_list.len > 0{
							app.actual_i = app.actual_i % app.dir_list.len
						}
						app.refresh = true
						app.last_event = 'paste'
					}
				}
				.up {
					if app.dir_list != [] {
						if (app.actual_i - 1) == -1 {
							app.actual_i = app.dir_list.len - 1
							if app.dir_list.len > app.tui.window_height - 5 {
								app.actual_scroll = -app.tui.window_height + 8 + app.actual_i
							}
						} else {
							app.actual_i = app.actual_i - 1
						}
						if app.dir_list.len > app.tui.window_height - 5 {
							if app.actual_i - 3 < app.actual_scroll  {
								if app.actual_scroll > 0 {
									app.actual_scroll -= 1
								}
							}
						}
					}
					app.last_event = 'up'
				}
				.down {
					if app.dir_list != [] {
						app.actual_i = (app.actual_i + 1) % app.dir_list.len
						if app.dir_list.len > app.tui.window_height - 5 {
							if app.actual_i - app.actual_scroll > app.tui.window_height - 8 {
								app.actual_scroll = -app.tui.window_height + 8 + app.actual_i
							} else {
								if app.actual_i == 0 {
									app.actual_scroll = 0
								}
							}
						}
					}
					app.last_event = 'down'
				}
				.left {
					app.actual_path = os.abs_path(os.dir(app.actual_path) + '\\')
					os.chdir(app.actual_path) or {
						er('left chdir ${err} ${app.actual_path}')
						''
					}
					app.last_event = 'left'
				}
				.right {
					app.go_in()
					app.actual_scroll = 0
				}
				.enter {
					app.go_in()
					app.actual_scroll = 0
				}
				.n {
					if !e.modifiers.has(.shift) {
						app.edit_mode = 'Name of the new file:'
						app.last_event = 'new_file'
					}else{
						app.edit_mode = 'Name of the new folder:'
						app.last_event = 'new_dir'
					}
				}
				.r {
					app.update_dir_list()
					if app.dir_list.len > 0{
						app.actual_i = app.actual_i % app.dir_list.len
					}
					app.refresh = true
					app.last_event = 'refresh'
				}
				.delete {
					if app.dir_list != [] {
						if !os.is_dir(app.dir_list[app.actual_i]) {
							app.question_mode = "Delete this file ?"
						}else{
							if e.modifiers.has(.shift) {
								app.question_mode = "Delete this folder ?"
							}
						}
						app.last_event = 'delete'
					}
				}
				.escape {
					exit(0)
				}
				.q {
					exit(0)
				}
				.f {
					app.fav_mode = true
					app.last_event = 'fav mode'
				}
				.space {
					app.search_mode = true
					app.search_text = ""
					app.last_event = 'search mode'
				}
				else {
					if e.code.str() in app.key_binds {
						spawn os.execute(app.key_binds[e.code.str()])
						app.refresh = true
						app.last_event = 'exec'
					}
				}
			}
		}
		
	}else if e.typ == .resized {
		app.refresh = true
	}
}

fn (mut app App) render() {
	app.tui.clear()
	app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
	//app.tui.draw_rect(0, 0, app.tui.window_width, app.tui.window_height)
	app.tui.set_color(r: 255, g: 255, b: 255) // white font

	
	app.tui.draw_text(0, 0, '${app.actual_path}')
	app.tui.draw_text(app.tui.window_width-app.copy_path.len-12, 0, 'Clipboard : ${app.copy_path}')
	// Draw the files
	app.tui.set_color(r: app.folder_font[0], g: app.folder_font[1], b: app.folder_font[2]) // color for dirs
	mut encountered_file := false
	if app.chdir_error == '' {
		for i, file in app.dir_list {
			if i - app.actual_scroll < app.tui.window_height && i - app.actual_scroll >= 0 {	
				pos := -app.actual_scroll + i + 3
 				if os.is_dir(file) {
					if i == app.actual_i {
						app.tui.set_bg_color(r: app.folder_highlight[0], g: app.folder_highlight[1], b: app.folder_highlight[2])
						app.tui.draw_text(1, pos, '> ${file}')
						app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
					} else {
						app.tui.draw_text(1, pos, '  ${file}')
					}
				} else {
					if encountered_file == false {
						app.tui.set_color(r: 255, g: 255, b: 255) // file font color
						encountered_file = true
					}
					if i == app.actual_i {
						app.tui.set_bg_color(r: app.file_highlight[0], g: app.file_highlight[1], b: app.file_highlight[2])
						app.tui.draw_text(1, pos, '> ${file}')
						app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
					} else {
						app.tui.draw_text(1, pos, '  ${file}')
					}
				}
			}
		}
		if app.dir_list.len == 0 {
			app.tui.draw_text(2, 3, 'Empty directory')
		} else {
			if app.search_results != [] && app.search_i != -1 {
				date := time.Time{}.add_seconds(int(os.file_last_mod_unix(app.search_results[app.search_i])))
				bottom_text := '${(if !os.is_dir(app.search_results[app.search_i]) {space_nb(os.file_size(app.search_results[app.search_i]).str()) + 'o'} else {'Directory'}):-15} | Modified the ${date.local().format_ss():-15} | ${os.abs_path(app.search_results[app.search_i])}'
				app.tui.draw_text(0, app.tui.window_height, if bottom_text.len > app.tui.window_width {bottom_text[0..app.tui.window_width]} else {bottom_text})
			}else{
				date := time.Time{}.add_seconds(int(os.file_last_mod_unix(app.dir_list[app.actual_i])))
				bottom_text := '${(if !os.is_dir(app.dir_list[app.actual_i]) {space_nb(os.file_size(app.dir_list[app.actual_i]).str()) + 'o'} else {'Directory'}):-15} | Modified the ${date.local().format_ss():-15} | ${os.abs_path(app.dir_list[app.actual_i])}'
				app.tui.draw_text(0, app.tui.window_height, if bottom_text.len > app.tui.window_width {bottom_text[0..app.tui.window_width]} else {bottom_text})
			}
		}
	} else {
		app.tui.draw_text(1, 2, app.chdir_error)
	}
	app.tui.set_color(r: 255, g: 255, b: 255)

	// Draw the box around the files
	app.draw_box(0, 2, app.tui.window_width, app.tui.window_height-1)
	app.tui.draw_text(3, 2, app.sort_name)

	if app.edit_mode != "" {
		app.draw_box(app.tui.window_width/2-50, (app.tui.window_height-1)/2-2, app.tui.window_width/2+50, (app.tui.window_height-1)/2+1)
		app.tui.draw_text(app.tui.window_width/2-49, (app.tui.window_height-1)/2-1, app.edit_mode)
		app.tui.draw_text(app.tui.window_width/2-49, (app.tui.window_height-1)/2, app.edit_text)
	}else if app.question_mode != "" {
		app.draw_box(app.tui.window_width/2-15, (app.tui.window_height-1)/2-2, app.tui.window_width/2+15, (app.tui.window_height-1)/2+1)
		app.tui.draw_text(app.tui.window_width/2-9, (app.tui.window_height-1)/2-1, app.question_mode)
		if app.question_answer{
			app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
			app.tui.draw_text(app.tui.window_width/2-3, (app.tui.window_height-1)/2,"No")
			app.tui.set_bg_color(r: app.choice_highlight[0], g: app.choice_highlight[1], b: app.choice_highlight[2])
		}else{
			app.tui.set_bg_color(r: app.choice_highlight[0], g: app.choice_highlight[1], b: app.choice_highlight[2])
			app.tui.draw_text(app.tui.window_width/2-3, (app.tui.window_height-1)/2,"No")
			app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
		}
		app.tui.draw_text(app.tui.window_width/2, (app.tui.window_height-1)/2, "Yes")
		app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
	}else if app.fav_mode {
		app.draw_box(app.tui.window_width/2-30, (app.tui.window_height-1)/2-10, app.tui.window_width/2+30, (app.tui.window_height-1)/2+10)
		app.tui.draw_text(app.tui.window_width/2-28, (app.tui.window_height-1)/2-10, "Favorites")
		for i, fav in app.fav_folders {
			if app.fav_index == i {
				app.tui.set_bg_color(r: app.fav_highlight[0], g: app.fav_highlight[1], b: app.fav_highlight[2])
			}
			app.tui.draw_text(app.tui.window_width/2-28, (app.tui.window_height-1)/2-9+i, fav)
			if app.fav_index == i {
				app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
			}
		}
	} else if app.cmd_mode {
		app.draw_box(app.tui.window_width/10, (app.tui.window_height-1)/2-1, app.tui.window_width*9/10, (app.tui.window_height-1)/2+1)
		app.tui.draw_text(app.tui.window_width/10+2, (app.tui.window_height-1)/2-1, "Enter your command")
		app.tui.draw_text(app.tui.window_width/10+2, (app.tui.window_height-1)/2, "> $app.cmd_text")
	} else if app.search_mode {
		if app.search_results != [] {
			if app.search_results.len + 8 + 5 > app.tui.window_height {
				app.draw_box(app.tui.window_width/10, 5, app.tui.window_width*9/10, app.tui.window_height-4)
				app.draw_bar(app.tui.window_width/10, 7, app.tui.window_width*9/10)
				for i, result in app.search_results[0..app.tui.window_height-8-4] {
					if i == app.search_i{
						app.tui.set_bg_color(r: app.search_highlight[0], g: app.search_highlight[1], b: app.search_highlight[2])
					}
					app.tui.draw_text(app.tui.window_width/10+1, 8+i, "> ${result[app.actual_path.len..]}")
					if i == app.search_i{
						app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
					}
				}
			} else {
				app.draw_box(app.tui.window_width/10, 5, app.tui.window_width*9/10, 7+app.search_results.len+1)
				app.draw_bar(app.tui.window_width/10, 7, app.tui.window_width*9/10)
				for i, result in app.search_results {
					if i == app.search_i{
						app.tui.set_bg_color(r: app.search_highlight[0], g: app.search_highlight[1], b: app.search_highlight[2])
					}
					app.tui.draw_text(app.tui.window_width/10+1, 8+i, "> ${result[app.actual_path.len..]}")
					if i == app.search_i{
						app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
					}
				}
			}
		}else {
			if app.search_success{
				app.draw_box(app.tui.window_width/10, 5, app.tui.window_width*9/10, 7+1+1)
				app.draw_bar(app.tui.window_width/10, 7, app.tui.window_width*9/10)
				app.tui.draw_text(app.tui.window_width/10+2, 8, " No results")
			}else{
				app.draw_box(app.tui.window_width/10, 5, app.tui.window_width*9/10, 7)
			}
		}
		if app.search_success {
			app.tui.draw_text(app.tui.window_width/10+2, 5, "Search - ${app.search_time}s")
		}else {
			app.tui.draw_text(app.tui.window_width/10+2, 5, "Search")
		}
		app.tui.draw_text(app.tui.window_width/10+3, 6, "${app.search_text}")
	}

	app.tui.set_cursor_position(0, 0)

	app.tui.reset()
	app.tui.flush()
}

fn frame(x voidptr) {
	mut app := unsafe { &App(x) }
	mut ask_render := false
	app.frame_nb = (app.frame_nb + 1) % 3600
	if app.old_actual_path != app.actual_path {
		app.update_dir_list()
		ask_render = true
		//app.actual_i = app.find_last_dir()
		app.actual_i = 0
		app.old_actual_path = app.actual_path
	} else {
		if app.frame_nb % 360 == 0 {
		}
	}
	if app.refresh{
		ask_render = true
		app.refresh = false
	}
	if app.old_actual_i != app.actual_i {
		ask_render = true
		app.old_actual_i = app.actual_i
	}else if app.old_edit_mode != app.edit_mode{
		ask_render = true
		app.old_edit_mode = app.edit_mode
	}else if app.old_edit_text != app.edit_text{
		ask_render = true
		app.old_edit_text = app.edit_text
	}else if app.old_question_answer != app.question_answer{
		ask_render = true
		app.old_question_answer = app.question_answer
	}else if app.old_question_mode != app.question_mode{
		ask_render = true
		app.old_question_mode = app.question_mode
	}else if app.old_fav_mode != app.fav_mode {
		ask_render = true
		app.old_fav_mode = app.fav_mode
	}else if app.old_fav_index != app.fav_index {
		ask_render = true
		app.old_fav_index = app.fav_index
	}else if app.old_cmd_mode != app.cmd_mode {
		ask_render = true
		app.old_cmd_mode = app.cmd_mode
	}else if app.old_cmd_text != app.cmd_text {
		ask_render = true
		app.old_cmd_text = app.cmd_text
	}else if app.old_search_mode != app.search_mode {
		ask_render = true
		app.old_search_mode = app.search_mode
	}else if app.old_search_text != app.search_text {
		ask_render = true
		app.old_search_text = app.search_text
	}else if app.old_search_i != app.search_i {
		ask_render = true
		app.old_search_i = app.search_i
	}

	if ask_render {
		app.render()
	}
}

fn (mut app App) initialisation() {
	app.tui.set_color(r: 255, g: 255, b: 255)
	app.update_dir_list()
	app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
	//app.tui.draw_rect(0, 0, app.tui.window_width, app.tui.window_height)
}

fn main() {
	println(start_path)
	mut app := &App{}
	config := toml.parse_file("config.toml") or {er("Config file error $err"); println("juujuj"); toml.Doc{}}
	if config.value('exts_n_paths') == toml.Any(toml.Null{}) {
		er("read config file error")
	}	

	tmp_array := config.value('exts_n_paths').array().map(it.string())
	for i, elem in tmp_array{
		if i%2 == 0{
			app.associated_apps[elem] = tmp_array[i+1]
		}
	}
	app.fav_folders = config.value('favorite_folders').array().map(it.string())
	app.bg_color = config.value('bg_color').array().map(u8(it.int()))
	app.folder_highlight = config.value('folder_highlight').array().map(u8(it.int()))
	app.choice_highlight = config.value('choice_highlight').array().map(u8(it.int()))
	app.folder_font = config.value('folder_font').array().map(u8(it.int()))
	app.file_highlight = config.value('file_highlight').array().map(u8(it.int()))
	app.fav_highlight = config.value('fav_highlight').array().map(u8(it.int()))
	app.search_highlight = config.value('search_highlight').array().map(u8(it.int()))

	tmp_keybinds := config.value('keybinds').array().map(it.array())
	mut keybinds := [][]string{}
	for elem in tmp_keybinds {
		keybinds << elem.map(it.string())
	}
	for pair in keybinds {
		app.key_binds[pair[0]] = pair[1]
	}


	// os.ls()
	// os.abs_path()
	// os.is_dir()
	// os.is_dir_empty()
	// os.is_file()
	/*
	os.file_name(opath string) string
	os.file_ext(app.dir_list[app.actual_i])
	fn chdir(path string) !
chdir changes the current working directory to the new directory in path.

fn getwd() string
getwd returns the absolute path of the current directory.

fn dir(opath string) string
dir returns all but the last element of path, typically the path's directory.
After dropping the final element, trailing slashes are removed.
If the path is empty, dir returns ".". If the path consists entirely of separators, dir returns a single separator.
The returned path does not end in a separator unless it is the root directory.
	*/
	app.tui = tui.init(
		user_data: app
		event_fn: event
		frame_fn: frame
		hide_cursor: true
	)
	app.initialisation()
	app.tui.run()!
}