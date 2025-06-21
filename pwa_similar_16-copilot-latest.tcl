#!/usr/bin/env wish
package require Tk
package require http

# Создаем namespace для всплывающих подсказок
namespace eval tooltip {
    variable pending ""
    variable current ""
    variable delay 500
    variable fade 100
    variable bg "#FFFFC0"
    variable fg "#000000"
    
    proc show {win msg} {
        variable pending
        variable current
        variable delay
        
        # Отменяем отложенное действие, если оно было запланировано
        if {$pending ne ""} {
            after cancel $pending
            set pending ""
        }
        
        # Скрываем текущую подсказку, если она видима
        if {$current ne ""} {
            hide
        }
        
        # Запланируем отображение подсказки
        set pending [after $delay [list tooltip::display $win $msg]]
    }

    proc display {win msg} {
        variable pending
        variable current
        variable bg
        variable fg
        
        set pending ""
        set current $win
        
        # Создаем окно подсказки
        toplevel .tooltip
        wm overrideredirect .tooltip 1
        wm attributes .tooltip -topmost 1
        
        # Добавляем метку с текстом подсказки
        label .tooltip.label -text $msg -background $bg -foreground $fg -padx 5 -pady 2 -relief solid -borderwidth 1
        pack .tooltip.label
        
        # Позиционируем подсказку около виджета
        set x [winfo rootx $win]
        set y [expr {[winfo rooty $win] + [winfo height $win] + 3}]
        wm geometry .tooltip +$x+$y
    }

    proc hide {{fadeOut 1}} {
        variable pending
        variable current
        variable fade
        
        # Отменяем отложенное действие, если оно было запланировано
        if {$pending ne ""} {
            after cancel $pending
            set pending ""
        }
        
        # Скрываем подсказку, если она видима
        if {$current ne ""} {
            set current ""
            if {$fadeOut && $fade > 0} {
                # Плавное исчезновение
                for {set i 100} {$i >= 0} {incr i -10} {
                    if {[winfo exists .tooltip]} {
                        wm attributes .tooltip -alpha [expr {$i / 100.0}]
                        update
                        after 10
                    }
                }
            }
            if {[winfo exists .tooltip]} {
                destroy .tooltip
            }
        }
    }

    proc tooltip {win msg} {
        bind $win <Enter> [list tooltip::show %W $msg]
        bind $win <Leave> [list tooltip::hide]
        bind $win <Button> [list tooltip::hide]
    }
}

# Создаем главное окно
wm title . "PWA Similar Manager"
wm geometry . 800x600

# Центрирование главного окна
set screen_width [winfo screenwidth .]
set screen_height [winfo screenheight .]
set x [expr {($screen_width - 800) / 2}]
set y [expr {($screen_height - 600) / 2}]
wm geometry . "+$x+$y"

# Глобальные переменные
global app_to_url tab_list
set app_to_url [dict create]
set tab_list {}

# Значения по умолчанию для стилей
set default_font_color "#000000"
set default_bg_color "#FFFFFF"
set default_list_font_size 12
set default_control_font_size 10
set default_line_spacing 1

# Создаем директорию для иконок
proc ensure_icon_directory {} {
    set icon_dir [file join [pwd] "icons"]
    if {![file exists $icon_dir]} {
        file mkdir $icon_dir
    }
    return $icon_dir
}

# Чтение конфигурации из файла config.conf
proc load_config {} {
    global font_color bg_color list_font_size control_font_size line_spacing
    set config_file "config.conf"
    if {[file exists $config_file]} {
        set fd [open $config_file r]
        while {[gets $fd line] >= 0} {
            set parts [split $line "="]
            if {[llength $parts] == 2} {
                set key [string trim [lindex $parts 0]]
                set value [string trim [lindex $parts 1]]
                switch $key {
                    "font_color" {
                        if {[regexp {^#[0-9A-Fa-f]{6}$} $value]} { set font_color $value }
                    }
                    "bg_color" {
                        if {[regexp {^#[0-9A-Fa-f]{6}$} $value]} { set bg_color $value }
                    }
                    "list_font_size" { set list_font_size $value }
                    "control_font_size" { set control_font_size $value }
                    "line_spacing" { set line_spacing $value }
                }
            }
        }
        close $fd
    }
    if {![info exists font_color]} { set font_color $::default_font_color }
    if {![info exists bg_color]} { set bg_color $::default_bg_color }
    if {![info exists list_font_size]} { set list_font_size $::default_list_font_size }
    if {![info exists control_font_size]} { set control_font_size $::default_control_font_size }
    if {![info exists line_spacing]} { set line_spacing $::default_line_spacing }
}

# Функция для скачивания иконки через Bash-скрипт
proc download_icon {url app_name} {
    set script_path [file join [pwd] "download_icon.sh"]
    if {[catch {set result [exec $script_path $url $app_name 2>@1]} error]} {
        puts "Error executing Bash script: $error"
        return ""
    }
    set lines [split $result "\n"]
    set icon_path ""
    foreach line $lines {
        set line [string trim $line]
        if {[file exists $line] && [string match "*.png" $line]} {
            set icon_path $line
            break
        }
    }
    return $icon_path
}

# Функция для проверки валидности иконки
proc is_valid_icon {icon_path} {
    if {$icon_path eq "" || ![file exists $icon_path]} { return 0 }
    if {[file size $icon_path] == 0} { return 0 }
    if {[catch {set file_type [exec file -b --mime-type $icon_path]}]} { return 0 }
    return [string match "image/*" $file_type]
}

# Функция для отображения модального окна с прогрессом
proc show_progress_window {} {
    global font_color bg_color control_font_size
    toplevel .progress_win
    wm title .progress_win "Создание приложения"
    wm geometry .progress_win 300x100
    set x [expr {([winfo screenwidth .] - 300) / 2}]
    set y [expr {([winfo screenheight .] - 100) / 2}]
    wm geometry .progress_win "+$x+$y"
    wm transient .progress_win .
    wm attributes .progress_win -topmost 1
    grab set .progress_win
    .progress_win configure -background $bg_color
    label .progress_win.label -text "Создание приложения, пожалуйста подождите..." -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
    place .progress_win.label -x 20 -y 20
    after 2000 {destroy .progress_win}
}

# Функция для отправки уведомления через notify-send
proc send_notification {title message {icon ""}} {
    if {$icon eq ""} {
        exec notify-send "$title" "$message" &
    } else {
        exec notify-send -i "$icon" "$title" "$message" &
    }
}

# Сохранение плейлиста для каждой вкладки
proc save_playlist {tab_name} {
    global app_to_url
    set playlist_file "playlist_$tab_name.txt"
    if {[catch {
        set fd [open $playlist_file w]
        set apps [dict get $app_to_url $tab_name]
        dict for {app_name url} $apps {
            # Сохраняем только записи приложений, но не служебные ключи
            if {![string match "*.create_desktop" $app_name]} {
                puts $fd "$app_name $url"
            }
        }
        close $fd
        puts "Playlist saved: $playlist_file"
    } error]} {
        puts "Error saving playlist $playlist_file: $error"
    }
}

# Сохранение порядка вкладок
proc save_tab_order {} {
    global tab_list
    set order_file "tabs_order.txt"
    if {[catch {
        set fd [open $order_file w]
        foreach tab $tab_list {
            puts $fd $tab
        }
        close $fd
        puts "Tab order saved: $order_file"
    } error]} {
        puts "Error saving tab order: $error"
    }
}

# Проверка и создание/обновление .desktop файлов
proc check_and_create_desktops {} {
    global app_to_url tab_list
    set desktop_dir "/home/live/.local/share/applications"
    set icon_dir [ensure_icon_directory]
    set default_icon [file join $icon_dir "web_apps.png"]

    # Убедимся, что директория для .desktop файлов существует
    if {![file exists $desktop_dir]} {
        file mkdir $desktop_dir
    }

    foreach tab_name $tab_list {
        set apps [dict get $app_to_url $tab_name]
        dict for {app_name url} $apps {
            # Проверяем наличие флага create_desktop
            if {![string match "*.create_desktop" $app_name] && 
                [dict exists $apps "$app_name.create_desktop"] && 
                [dict get $apps "$app_name.create_desktop"]} {
                set desktop_file [file join $desktop_dir "$app_name.desktop"]
                set downloaded_icon [file join $icon_dir "${app_name}.png"]
                set icon_path ""

                # Определяем путь к иконке
                if {[file exists $downloaded_icon] && [is_valid_icon $downloaded_icon]} {
                    set icon_path $downloaded_icon
                } elseif {[file exists $default_icon] && [is_valid_icon $default_icon]} {
                    set icon_path $default_icon
                } else {
                    set icon_path "application-x-executable"
                }

                # Проверяем, нужно ли создать или обновить .desktop файл
                set needs_update 0
                if {[file exists $desktop_file]} {
                    # Читаем текущий файл и проверяем путь к иконке
                    set fd [open $desktop_file r]
                    set content [read $fd]
                    close $fd
                    if {[regexp {Icon=(.+)} $content match current_icon]} {
                        if {$current_icon ne $icon_path && ![file exists $current_icon]} {
                            set needs_update 1
                        }
                    }
                } else {
                    set needs_update 1
                }

                # Создаем или обновляем .desktop файл
                if {$needs_update} {
                    if {[catch {
                        set fd [open $desktop_file w]
                        puts $fd {[Desktop Entry]}
                        puts $fd {Type=Application}
                        puts $fd "Name=$app_name"
                        puts $fd "Exec=xdg-open $url"
                        puts $fd "Icon=$icon_path"
                        puts $fd {Terminal=false}
                        puts $fd {Categories=Network;}
                        close $fd
                        puts "Created/Updated desktop file: $desktop_file with icon: $icon_path"
                    } error]} {
                        puts "Error creating/updating desktop file $desktop_file: $error"
                    }
                }
            }
        }
    }
}

# Функция для экспорта в tar.gz
proc export_to_archive {} {
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set archive_name "pwa_manager_backup_$today.tar.gz"
    
    send_notification "PWA Similar Manager" "Начало экспорта в архив $archive_name"
    
    # Создаем список файлов для экспорта
    set file_list {}
    lappend file_list "config.conf" "tabs_order.txt"
    foreach tab $::tab_list {
        lappend file_list "playlist_$tab.txt"
    }
    lappend file_list "icons"
    
    if {[catch {
        # Создаем архив
        exec tar -czf $archive_name {*}$file_list
        send_notification "PWA Similar Manager" "Экспорт успешно завершен: $archive_name" "dialog-information"
    } error]} {
        send_notification "PWA Similar Manager" "Ошибка при создании архива: $error" "dialog-error"
        puts "Error creating archive: $error"
    }
}

# Функция для импорта из архива
proc import_from_archive {} {
    set types {
        {"Архивы tar.gz" {.tar.gz}}
        {"Все файлы" *}
    }
    set file [tk_getOpenFile -filetypes $types -title "Выберите архив для импорта"]
    if {$file ne ""} {
        send_notification "PWA Similar Manager" "Начало импорта из архива $file"
        if {[catch {
            # Распаковываем архив
            exec tar -xzf $file
            send_notification "PWA Similar Manager" "Импорт успешно завершен, перезапустите приложение для применения изменений" "dialog-information"
            after 2000 {
                exit
            }
        } error]} {
            send_notification "PWA Similar Manager" "Ошибка при импорте архива: $error" "dialog-error"
            puts "Error importing archive: $error"
        }
    }
}

# Функция для fuzzy поиска
proc fuzzy_match {pattern text} {
    # Преобразуем в нижний регистр для регистронезависимого поиска
    set pattern [string tolower $pattern]
    set text [string tolower $text]
    
    # Если строка пустая, возвращаем 1 (совпадение)
    if {$pattern eq ""} {
        return 1
    }
    
    # Если текст пустой, а шаблон нет, возвращаем 0 (несовпадение)
    if {$text eq ""} {
        return 0
    }
    
    # Проверяем, содержит ли текст все символы из шаблона в правильном порядке
    set p_idx 0
    set p_len [string length $pattern]
    set t_idx 0
    set t_len [string length $text]
    
    while {$p_idx < $p_len && $t_idx < $t_len} {
        set p_char [string index $pattern $p_idx]
        set t_char [string index $text $t_idx]
        
        if {$p_char eq $t_char} {
            incr p_idx
        }
        
        incr t_idx
    }
    
    # Если мы прошли весь шаблон, значит нашли совпадение
    return [expr {$p_idx == $p_len}]
}

# Загружаем конфигурацию
load_config

# Создаем кастомный шрифт для списка
font create ListFont -family "TkDefaultFont" -size $list_font_size
. configure -background $bg_color

# Убедимся, что директория для иконок существует
ensure_icon_directory

# Создаем фрейм для поиска и кнопок управления
frame .controls -background $bg_color
pack .controls -side top -fill x -padx 10 -pady 5

# Поле для fuzzy поиска
label .controls.search_label -text "Поиск:" -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
pack .controls.search_label -side left -padx 2
entry .controls.search_entry -width 20 -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
pack .controls.search_entry -side left -padx 2

# Привязываем событие изменения текста к функции поиска
bind .controls.search_entry <KeyRelease> {perform_fuzzy_search}

# Кнопка очистки поиска
button .controls.clear_search -text "✕" -command {
    .controls.search_entry delete 0 end
    perform_fuzzy_search
} -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -width 1
pack .controls.clear_search -side left -padx 2

# Функция поиска в списке
proc perform_fuzzy_search {} {
    set search_text [.controls.search_entry get]
    set tab_name [get_current_tab]
    if {$tab_name ne ""} {
        set tab_id [string tolower $tab_name]
        
        # Сохраняем текущее выделение
        set selected_idx -1
        catch {set selected_idx [.tabs.$tab_id.list curselection]}
        
        # Очищаем и заполняем список заново
        .tabs.$tab_id.list delete 0 end
        
        set apps [dict get $::app_to_url $tab_name]
        set app_list {}
        dict for {app_name url} $apps {
            if {![string match "*.create_desktop" $app_name]} {
                lappend app_list $app_name
            }
        }
        
        # Добавляем элементы, соответствующие поиску
        set match_idx 0
        set found_selected 0
        foreach app_name $app_list {
            if {$search_text eq "" || [fuzzy_match $search_text $app_name]} {
                .tabs.$tab_id.list insert end $app_name
                
                # Восстанавливаем выделение, если это возможно
                if {$selected_idx == $match_idx} {
                    .tabs.$tab_id.list selection set $match_idx
                    .tabs.$tab_id.list see $match_idx
                    set found_selected 1
                }
                
                incr match_idx
            }
        }
        
        # Если не удалось восстановить выделение, выбираем первый элемент (если он есть)
        if {!$found_selected && $match_idx > 0 && $selected_idx >= 0} {
            .tabs.$tab_id.list selection set 0
            .tabs.$tab_id.list see 0
        }
    }
}

# Кнопки управления
button .controls.add_btn -text "+" -command show_add_window -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
pack .controls.add_btn -side left -padx 5

button .controls.del_btn -text "-" -command delete_url -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
pack .controls.del_btn -side left -padx 5

button .controls.add_tab_btn -text "Tab+" -command show_new_tab_window -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
pack .controls.add_tab_btn -side left -padx 5

button .controls.up_btn -text "↑" -command move_up -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
pack .controls.up_btn -side left -padx 5

button .controls.down_btn -text "↓" -command move_down -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
pack .controls.down_btn -side left -padx 5

# Добавляем новую кнопку для импорта/экспорта
button .controls.io_btn -text "⇄" -command show_io_window -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
pack .controls.io_btn -side left -padx 5

# Функция для отображения окна импорта/экспорта
proc show_io_window {} {
    global font_color bg_color control_font_size
    toplevel .io_win
    wm title .io_win "Импорт/Экспорт"
    wm geometry .io_win 300x150
    set x [expr {([winfo screenwidth .] - 300) / 2}]
    set y [expr {([winfo screenheight .] - 150) / 2}]
    wm geometry .io_win "+$x+$y"
    wm transient .io_win .
    wm attributes .io_win -topmost 1
    grab set .io_win
    .io_win configure -background $bg_color

    label .io_win.title -text "Выберите операцию:" -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
    place .io_win.title -x 20 -y 20

    button .io_win.export_btn -text "Экспорт в архив" -command {
        destroy .io_win
        export_to_archive
    } -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow -width 20
    place .io_win.export_btn -x 50 -y 50

    button .io_win.import_btn -text "Импорт из архива" -command {
        destroy .io_win
        import_from_archive
    } -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow -width 20
    place .io_win.import_btn -x 50 -y 90
}

# Создаем notebook для вкладок
ttk::notebook .tabs
pack .tabs -fill both -expand 1 -padx 10 -pady 5

# Привязываем смену вкладки к обновлению поиска
bind .tabs <<NotebookTabChanged>> {
    .controls.search_entry delete 0 end
    perform_fuzzy_search
}

# Функция добавления новой вкладки
proc add_tab {tab_name} {
    global tab_list app_to_url font_color bg_color list_font_size
    if {$tab_name ni $tab_list} {
        lappend tab_list $tab_name
        dict set app_to_url $tab_name [dict create]
        
        set tab_id [string tolower $tab_name]
        frame .tabs.$tab_id -background $bg_color
        listbox .tabs.$tab_id.list -font "ListFont" -foreground $font_color -background $bg_color
        pack .tabs.$tab_id.list -fill both -expand 1
        
        .tabs add .tabs.$tab_id -text $tab_name
        bind .tabs.$tab_id.list <Double-1> {launch_url}
        bind .tabs.$tab_id.list <Return> {launch_url}

        puts "Added new tab: $tab_name"
        save_playlist $tab_name
        save_tab_order
    }
}

# Загрузка порядка вкладок и создание их в интерфейсе
proc load_tab_order {} {
    global tab_list app_to_url
    set order_file "tabs_order.txt"
    if {[file exists $order_file]} {
        set fd [open $order_file r]
        set tab_list {}
        while {[gets $fd line] >= 0} {
            set tab_name [string trim $line]
            if {$tab_name ne "" && $tab_name ni $tab_list} {
                lappend tab_list $tab_name
                dict set app_to_url $tab_name [dict create]
                set tab_id [string tolower $tab_name]
                frame .tabs.$tab_id -background $::bg_color
                listbox .tabs.$tab_id.list -font "ListFont" -foreground $::font_color -background $::bg_color
                pack .tabs.$tab_id.list -fill both -expand 1
                .tabs add .tabs.$tab_id -text $tab_name
                bind .tabs.$tab_id.list <Double-1> {launch_url}
                bind .tabs.$tab_id.list <Return> {launch_url}
                puts "Loaded tab: $tab_name"
            }
        }
        close $fd
    } else {
        puts "No tab order file found, starting fresh"
    }
}

# Загрузка плейлистов
proc load_playlists {} {
    global tab_list app_to_url
    foreach tab_name $tab_list {
        set playlist_file "playlist_$tab_name.txt"
        set tab_id [string tolower $tab_name]
        if {[file exists $playlist_file]} {
            set fd [open $playlist_file r]
            while {[gets $fd line] >= 0} {
                set parts [split $line " "]
                if {[llength $parts] >= 2} {
                    set app_name [lindex $parts 0]
                    set url [join [lrange $parts 1 end] " "]
                    .tabs.$tab_id.list insert end $app_name
                    dict set app_to_url $tab_name $app_name $url
                    
                    # Добавляем флаг create_desktop по умолчанию для существующих элементов
                    # Проверим, есть ли .desktop файл для этого приложения
                    set desktop_file "/home/live/.local/share/applications/$app_name.desktop"
                    if {[file exists $desktop_file]} {
                        dict set app_to_url $tab_name "$app_name.create_desktop" 1
                    } else {
                        dict set app_to_url $tab_name "$app_name.create_desktop" 0
                    }
                    
                    puts "Loaded from $playlist_file: $app_name -> $url"
                }
            }
            close $fd
        } else {
            puts "No playlist file for tab: $tab_name"
        }
    }
}

# Загружаем порядок вкладок и их содержимое, затем проверяем .desktop файлы
load_tab_order
load_playlists
check_and_create_desktops

# Если нет вкладок, добавляем вкладку по умолчанию
if {[llength $tab_list] == 0} {
    add_tab "default"
}

# Получение текущей активной вкладки
proc get_current_tab {} {
    set current [.tabs select]
    if {$current eq ""} { return "" }
    set tab_id [lindex [split $current "."] 2]
    foreach tab_name $::tab_list {
        if {[string tolower $tab_name] eq $tab_id} {
            return $tab_name
        }
    }
    return ""
}

# Функция запуска
proc launch_url {} {
    global app_to_url
    set tab_name [get_current_tab]
    if {$tab_name ne ""} {
        set tab_id [string tolower $tab_name]
        set selected [.tabs.$tab_id.list curselection]
        if {$selected ne ""} {
            set app_name [.tabs.$tab_id.list get $selected]
            set url [dict get $app_to_url $tab_name $app_name]
            exec xdg-open $url &
        }
    }
}

# Функция удаления
proc delete_url {} {
    global app_to_url
    set tab_name [get_current_tab]
    if {$tab_name ne ""} {
        set tab_id [string tolower $tab_name]
        set selected [.tabs.$tab_id.list curselection]
        if {$selected ne ""} {
            set app_name [.tabs.$tab_id.list get $selected]
            set url [dict get $app_to_url $tab_name $app_name]
            
            # Проверяем, есть ли флаг create_desktop и если он установлен
            if {[dict exists $app_to_url $tab_name "$app_name.create_desktop"] && 
                [dict get $app_to_url $tab_name "$app_name.create_desktop"]} {
                set desktop_file "/home/live/.local/share/applications/$app_name.desktop"
                if {[file exists $desktop_file]} { file delete $desktop_file }
                set icon_path [file join [pwd] "icons" "${app_name}.png"]
                if {[file exists $icon_path]} { file delete $icon_path }
            }
            
            # Удаляем из словаря
            dict unset app_to_url $tab_name $app_name
            dict unset app_to_url $tab_name "$app_name.create_desktop"
            
            # Обновляем список с учетом текущего поиска
            perform_fuzzy_search
            
            # Сохраняем изменения
            save_playlist $tab_name
            
            # Отображаем уведомление
            send_notification "PWA Similar Manager" "Приложение '$app_name' удалено"
        }
    }
}

# Функция перемещения вверх
proc move_up {} {
    global app_to_url
    set tab_name [get_current_tab]
    if {$tab_name ne ""} {
        set tab_id [string tolower $tab_name]
        
        # Получаем индекс выбранного элемента и проверяем его валидность
        if {[catch {
            set selected [.tabs.$tab_id.list curselection]
            # Если выбрано несколько элементов, берем только первый
            if {[llength $selected] > 1} {
                set selected [lindex $selected 0]
            }
        } err]} {
            puts "Error getting selection: $err"
            return
        }
        
        # Продолжаем только если есть валидное выделение и оно больше 0
        if {$selected ne "" && [string is integer -strict $selected] && $selected > 0} {
            set app_name [.tabs.$tab_id.list get $selected]
            set url [dict get $app_to_url $tab_name $app_name]
            
            # Сохраняем флаг create_desktop (если есть)
            set create_desktop 0
            if {[dict exists $app_to_url $tab_name "$app_name.create_desktop"]} {
                set create_desktop [dict get $app_to_url $tab_name "$app_name.create_desktop"]
            }
            
            # Получаем полный список без фильтрации поиском
            set apps [dict get $app_to_url $tab_name]
            set full_app_list {}
            dict for {key val} $apps {
                if {![string match "*.create_desktop" $key]} {
                    lappend full_app_list $key
                }
            }
            
            # Находим реальный индекс элемента в полном списке
            set visible_items {}
            set search_text [.controls.search_entry get]
            foreach app $full_app_list {
                if {$search_text eq "" || [fuzzy_match $search_text $app]} {
                    lappend visible_items $app
                }
            }
            
            set real_app_name [lindex $visible_items $selected]
            set idx [lsearch -exact $full_app_list $real_app_name]
            
            # Если индекс > 0, перемещаем элемент вверх
            if {$idx > 0} {
                set new_app_list [lreplace $full_app_list $idx $idx]
                set new_app_list [linsert $new_app_list [expr {$idx - 1}] $real_app_name]
                
                # Обновляем порядок в словаре
                set new_apps [dict create]
                foreach app $new_app_list {
                    dict set new_apps $app [dict get $apps $app]
                    if {[dict exists $apps "$app.create_desktop"]} {
                        dict set new_apps "$app.create_desktop" [dict get $apps "$app.create_desktop"]
                    }
                }
                dict set app_to_url $tab_name $new_apps
                
                # Обновляем отображение
                perform_fuzzy_search
                
                # Пытаемся найти перемещенный элемент в новом списке и выделить его
                set new_idx 0
                foreach item $visible_items {
                    if {$item eq $real_app_name} {
                        if {$new_idx > 0} {
                            incr new_idx -1
                        }
                        .tabs.$tab_id.list selection clear 0 end
                        .tabs.$tab_id.list selection set $new_idx
                        .tabs.$tab_id.list see $new_idx
                        break
                    }
                    incr new_idx
                }
                
                save_playlist $tab_name
            }
        }
    }
}

# Функция перемещения вниз
proc move_down {} {
    global app_to_url
    set tab_name [get_current_tab]
    if {$tab_name ne ""} {
        set tab_id [string tolower $tab_name]
        
        # Получаем индекс выбранного элемента и проверяем его валидность
        if {[catch {
            set selected [.tabs.$tab_id.list curselection]
            # Если выбрано несколько элементов, берем только первый
            if {[llength $selected] > 1} {
                set selected [lindex $selected 0]
            }
        } err]} {
            puts "Error getting selection: $err"
            return
        }
        
        # Продолжаем только если есть валидное выделение
        if {$selected ne "" && [string is integer -strict $selected]} {
            set app_name [.tabs.$tab_id.list get $selected]
            set url [dict get $app_to_url $tab_name $app_name]
            
            # Сохраняем флаг create_desktop (если есть)
            set create_desktop 0
            if {[dict exists $app_to_url $tab_name "$app_name.create_desktop"]} {
                set create_desktop [dict get $app_to_url $tab_name "$app_name.create_desktop"]
            }
            
            # Получаем полный список без фильтрации поиском
            set apps [dict get $app_to_url $tab_name]
            set full_app_list {}
            dict for {key val} $apps {
                if {![string match "*.create_desktop" $key]} {
                    lappend full_app_list $key
                }
            }
            
            # Находим реальный индекс элемента в полном списке
            set visible_items {}
            set search_text [.controls.search_entry get]
            foreach app $full_app_list {
                if {$search_text eq "" || [fuzzy_match $search_text $app]} {
                    lappend visible_items $app
                }
            }
            
            set real_app_name [lindex $visible_items $selected]
            set idx [lsearch -exact $full_app_list $real_app_name]
            
            # Если индекс < max, перемещаем элемент вниз
            if {$idx < [expr {[llength $full_app_list] - 1}]} {
                set new_app_list [lreplace $full_app_list $idx $idx]
                set new_app_list [linsert $new_app_list [expr {$idx + 1}] $real_app_name]
                
                # Обновляем порядок в словаре
                set new_apps [dict create]
                foreach app $new_app_list {
                    dict set new_apps $app [dict get $apps $app]
                    if {[dict exists $apps "$app.create_desktop"]} {
                        dict set new_apps "$app.create_desktop" [dict get $apps "$app.create_desktop"]
                    }
                }
                dict set app_to_url $tab_name $new_apps
                
                # Обновляем отображение
                perform_fuzzy_search
                
                # Пытаемся найти перемещенный элемент в новом списке и выделить его
                set new_idx 0
                foreach item $visible_items {
                    if {$item eq $real_app_name} {
                        if {$new_idx < [expr {[llength $visible_items] - 1}]} {
                            incr new_idx
                        }
                        .tabs.$tab_id.list selection clear 0 end
                        .tabs.$tab_id.list selection set $new_idx
                        .tabs.$tab_id.list see $new_idx
                        break
                    }
                    incr new_idx
                }
                
                save_playlist $tab_name
            }
        }
    }
}

# Функция добавления новой вкладки через модальное окно
proc show_new_tab_window {} {
    global font_color bg_color control_font_size tab_list
    toplevel .new_tab_win
    wm title .new_tab_win "Новая вкладка"
    wm geometry .new_tab_win 300x150
    set x [expr {([winfo screenwidth .] - 300) / 2}]
    set y [expr {([winfo screenheight .] - 150) / 2}]
    wm geometry .new_tab_win "+$x+$y"
    wm transient .new_tab_win .
    wm attributes .new_tab_win -topmost 1
    grab set .new_tab_win
    .new_tab_win configure -background $bg_color

    label .new_tab_win.label -text "Введите имя новой вкладки:" -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
    place .new_tab_win.label -x 20 -y 20
    entry .new_tab_win.name_entry -width 30 -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
    place .new_tab_win.name_entry -x 20 -y 50

    button .new_tab_win.btn -text "Создать" -command {
        set tab_name [.new_tab_win.name_entry get]
        if {$tab_name ne "" && $tab_name ni $::tab_list} {
            add_tab $tab_name
            send_notification "PWA Similar Manager" "Создана новая вкладка: $tab_name"
            destroy .new_tab_win
        } else {
            tk_messageBox -message "Ошибка: Введите уникальное имя вкладки!" -type ok -icon error -parent .new_tab_win
        }
    } -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
    place .new_tab_win.btn -x 20 -y 90

    bind .new_tab_win.name_entry <Return> {
        set tab_name [.new_tab_win.name_entry get]
        if {$tab_name ne "" && $tab_name ni $::tab_list} {
            add_tab $tab_name
            send_notification "PWA Similar Manager" "Создана новая вкладка: $tab_name"
            destroy .new_tab_win
        } else {
            tk_messageBox -message "Ошибка: Введите уникальное имя вкладки!" -type ok -icon error -parent .new_tab_win
        }
    }
    focus .new_tab_win.name_entry
}

# Функция удаления вкладки
proc delete_tab {tab_name} {
    global app_to_url tab_list
    set response [tk_messageBox -message "Удалить вкладку '$tab_name' и её плейлист?" -type yesno -icon warning -parent .]
    if {$response eq "yes"} {
        set tab_id [string tolower $tab_name]
        set apps [dict get $app_to_url $tab_name]
        dict for {app_name url} $apps {
            # Удаляем только если это не служебный ключ и флаг create_desktop установлен
            if {![string match "*.create_desktop" $app_name] && 
                [dict exists $apps "$app_name.create_desktop"] && 
                [dict get $apps "$app_name.create_desktop"]} {
                set desktop_file "/home/live/.local/share/applications/$app_name.desktop"
                if {[file exists $desktop_file]} { file delete $desktop_file }
                set icon_path [file join [pwd] "icons" "${app_name}.png"]
                if {[file exists $icon_path]} { file delete $icon_path }
            }
        }
        set playlist_file "playlist_$tab_name.txt"
        if {[file exists $playlist_file]} { file delete $playlist_file }
        .tabs forget .tabs.$tab_id
        dict unset app_to_url $tab_name
        set tab_list [lremove $tab_list $tab_name]
        save_tab_order
        send_notification "PWA Similar Manager" "Вкладка '$tab_name' удалена"
    }
}

# Вспомогательная функция для удаления элемента из списка
proc lremove {list item} {
    set idx [lsearch -exact $list $item]
    if {$idx >= 0} {
        return [lreplace $list $idx $idx]
    }
    return $list
}

# Привязка кликов мыши к вкладкам - исправление ошибки с кликом на пустом месте
bind .tabs <Button-1> { 
    set idx [.tabs index @%x,%y]
    if {$idx ne ""} {
        .tabs select $idx
    }
}

bind .tabs <Button-3> {
    set tab_idx [.tabs index @%x,%y]
    if {$tab_idx ne ""} {
        set tab_name [.tabs tab $tab_idx -text]
        if {$tab_name ne ""} { delete_tab $tab_name }
    }
}

# Функция добавления приложения
proc show_add_window {} {
    global font_color bg_color control_font_size tab_list
    toplevel .add_win
    wm title .add_win "Добавить PWA"
    wm geometry .add_win 470x280
    set x [expr {([winfo screenwidth .] - 470) / 2}]
    set y [expr {([winfo screenheight .] - 280) / 2}]
    wm geometry .add_win "+$x+$y"
    wm transient .add_win .
    wm attributes .add_win -topmost 1
    grab set .add_win
    .add_win configure -background $bg_color

    label .add_win.label_tab -text "Категория (вкладка):" -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
    place .add_win.label_tab -x 20 -y 20
    ttk::combobox .add_win.tab_entry -values $tab_list -width 47
    place .add_win.tab_entry -x 20 -y 50
    label .add_win.tab_note -text "Оставьте пустым для новой категории" -font [list "TkDefaultFont" 8] -foreground $font_color -background $bg_color
    place .add_win.tab_note -x 20 -y 75

    label .add_win.label_name -text "Имя приложения (опционально):" -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
    place .add_win.label_name -x 20 -y 90
    entry .add_win.name_entry -width 50 -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
    place .add_win.name_entry -x 20 -y 120

    label .add_win.label_url -text "URL веб-приложения:" -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
    place .add_win.label_url -x 20 -y 150
    entry .add_win.url_entry -width 50 -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color
    place .add_win.url_entry -x 20 -y 180

    # Создаем переменную для чекбокса
    variable create_desktop_var 0
    checkbutton .add_win.create_desktop -text "Создать PWA (десктоп файл)" -variable create_desktop_var -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
    place .add_win.create_desktop -x 20 -y 210

    proc paste_from_clipboard {} {
        set clipboard_content [clipboard get]
        .add_win.url_entry delete 0 end
        .add_win.url_entry insert 0 $clipboard_content
    }

    proc create_application {url app_name tab_name create_desktop parent} {
        global app_to_url tab_list
        if {$url ne ""} {
            if {$app_name eq ""} {
                set app_name [string map {"https://" "" "http://" "" "/" "-"} $url]
            }
            if {$tab_name eq ""} {
                set tab_name "default-[llength $tab_list]"
            }
            if {$tab_name ni $tab_list} {
                add_tab $tab_name
            }

            set tab_id [string tolower $tab_name]
            dict set app_to_url $tab_name $app_name $url
            dict set app_to_url $tab_name "$app_name.create_desktop" $create_desktop

            if {$create_desktop} {
                show_progress_window
                send_notification "PWA Similar Manager" "Создание PWA '$app_name'" "system-run"

                set downloaded_icon [download_icon $url $app_name]
                set icon_dir [ensure_icon_directory]
                set default_icon [file join $icon_dir "web_apps.png"]
                set icon_path ""
                if {$downloaded_icon ne "" && [is_valid_icon $downloaded_icon]} {
                    set icon_path $downloaded_icon
                } elseif {[file exists $default_icon] && [is_valid_icon $default_icon]} {
                    set icon_path $default_icon
                } else {
                    set icon_path "application-x-executable"
                }

                set desktop_file "/home/live/.local/share/applications/$app_name.desktop"
                set fd [open $desktop_file w]
                puts $fd {[Desktop Entry]}
                puts $fd {Type=Application}
                puts $fd "Name=$app_name"
                puts $fd "Exec=xdg-open $url"
                puts $fd "Icon=$icon_path"
                puts $fd {Terminal=false}
                puts $fd {Categories=Network;}
                close $fd

                send_notification "PWA Similar Manager" "PWA '$app_name' создано успешно" "dialog-information"
                tk_messageBox -message "Создан .desktop файл:\n$desktop_file\nИконка: $icon_path" -type ok -parent $parent
            } else {
                send_notification "PWA Similar Manager" "Добавлена закладка '$app_name'" "dialog-information"
                tk_messageBox -message "Закладка '$app_name' добавлена в вкладку '$tab_name'" -type ok -parent $parent
            }

            # Обновляем список в текущей вкладке
            perform_fuzzy_search
            
            save_playlist $tab_name
            destroy $parent
        } else {
            tk_messageBox -message "Ошибка: Введите URL!" -type ok -icon error -parent $parent
        }
    }

    button .add_win.btn -text "Создать" -command {
        create_application [.add_win.url_entry get] [.add_win.name_entry get] [.add_win.tab_entry get] $create_desktop_var .add_win
    } -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
    place .add_win.btn -x 20 -y 240
    
    button .add_win.paste_btn -text "Вставить из буфера" -command paste_from_clipboard -font [list "TkDefaultFont" $control_font_size] -foreground $font_color -background $bg_color -cursor arrow
    place .add_win.paste_btn -x 150 -y 240

    bind .add_win.url_entry <Return> {
        create_application [.add_win.url_entry get] [.add_win.name_entry get] [.add_win.tab_entry get] $create_desktop_var .add_win
    }
    bind .add_win.name_entry <Return> {
        create_application [.add_win.url_entry get] [.add_win.name_entry get] [.add_win.tab_entry get] $create_desktop_var .add_win
    }
    bind .add_win.tab_entry <Return> {
        create_application [.add_win.url_entry get] [.add_win.name_entry get] [.add_win.tab_entry get] $create_desktop_var .add_win
    }
    bind .add_win.url_entry <Control-v> {paste_from_clipboard}

    focus .add_win.tab_entry
}

# Устанавливаем горячие клавиши для поиска
bind . <Control-f> {focus .controls.search_entry; .controls.search_entry selection range 0 end}
bind . <Escape> {.controls.search_entry delete 0 end; perform_fuzzy_search}

# Инициализируем интерфейс поиска
perform_fuzzy_search

# Добавляем всплывающие подсказки для элементов
tooltip::tooltip .controls.search_entry "Нечёткий поиск в текущей вкладке (Ctrl+F)"
tooltip::tooltip .controls.clear_search "Очистить поиск (Esc)"
tooltip::tooltip .controls.add_btn "Добавить новое приложение"
tooltip::tooltip .controls.del_btn "Удалить выбранное приложение"
tooltip::tooltip .controls.add_tab_btn "Добавить новую вкладку"
tooltip::tooltip .controls.up_btn "Переместить приложение вверх"
tooltip::tooltip .controls.down_btn "Переместить приложение вниз"
tooltip::tooltip .controls.io_btn "Импорт/экспорт приложений"