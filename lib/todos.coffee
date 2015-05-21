###
Copyright 2014 Giampiero De Ciantis. The license text can be found in the
`LICENSE` file provided with this project.'

Description:
  All logic for commands in gpd.atom. These commands can create, move, complete,
  and repeat GPD todos. Also commands for toggling the Notes view.
###

_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
{exec, child} = require 'child_process'
moment = require 'moment'
PomodoroTimer = require './pomodoro-timer'
PomodoroView = require './pomodoro-view'


todo_header_string = '//Todo//'
closed_header_string = '//Closed//'
today_header_string = '//Today//'
footer_string = '//End//'
note_header_pattern = /`\(([a-zA-Z0-9_\"\., ]*)\)/
playSounds: false

module.exports =
  config:
    pomodoroLengthMinutes:
      type: 'integer'
      default: '25'
      minimum: '1'
    restLengthMinutes:
      type: 'integer'
      default: '5'
      minimum: '1'
    dateFormat:
      type: 'string'
      default: "YYYY-MM-DD hh:mm"

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:new-todo': => @new_todo()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:select-todo': => @select_todo()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:done-todo': => @done_todo()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:done-todo-and-repeat': => @done_todo_and_repeat()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:toggle-note': =>
      editor = @get_editor()
      editor.transact =>
        switch editor.getGrammar().scopeName
          when 'source.GPD_Note' then @open_todo()
          when 'source.GPD' then @open_note()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:start_timer': => @start()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:abort_timer': => @abort()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:toggle-pomodoro': => @toggle_pomodoro()
    @timer = new PomodoroTimer()
    @view = new PomodoroView(@timer)
    @timer.on 'finished', => @finish()
    @timer.on 'rest', => @start_rest()
    @timer.on 'start', =>
      @pomodoro_state = "STARTED"

  get_editor: -> atom.workspace.getActiveTextEditor()

  consumeStatusBar: (statusBar) ->
    @statusBarTile = statusBar.addLeftTile(item: @view, priority: 100)

  toggle_pomodoro: ->
    if @pomodoro_state == "STARTED"
      @abort()
    else
      @start()

  attempt: (fn) ->
    editor = @get_editor()
    if editor.getGrammar().scopeName == 'source.GPD'
      editor.transact =>
        if !fn.call(@)
          editor.abortTransaction()

  select_todo: -> @attempt(-> @move_todo_to_section 'Today')

  done_todo: -> @attempt(@close_todo)

  new_todo: -> @attempt(@create_todo)

  done_todo_and_repeat: -> @attempt(-> @add_to_todo() && @close_todo())

  is_header: (text) ->
    header_pattern = new RegExp('//(.*)//')
    header_pattern.test(text)

  move_todo_to_section: (section, prefix) ->
    editor = @get_editor()
    cur_line = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    end_of_line = editor.getCursorBufferPosition()
    editor.setSelectedBufferRange([[cur_line.row,0],end_of_line])
    todo = editor.getSelectedText()
    todo = todo.replace(/(^\s+|\s+$)/g,'')
    if !@is_header(editor.getSelectedText())
      editor.delete()
      editor.delete()
      range = [[0,0], editor.getEofBufferPosition()]
      header_regex = _.escapeRegExp('//' + section + '//')
      editor.scanInBufferRange new RegExp(header_regex, 'g'), range, (result) ->
        result.stop()
        editor.setCursorBufferPosition(result.range.end)
        editor.insertNewline()
        editor.moveToBeginningOfLine()
        editor.insertText('  ')
        if typeof prefix != 'undefined'
          editor.insertText(prefix)
        editor.insertText(todo)
        paste_line = editor.getCursorBufferPosition()
        if paste_line.row < cur_line.row
          editor.setCursorBufferPosition([cur_line.row + 1, 0])
        else
          editor.setCursorBufferPosition([cur_line.row, 0])
      return true
    else
      console.log("Can't move section marker")
      editor.setCursorBufferPosition(cur_line)
      return false

  create_todo: ->
    console.log("Creating todo")
    editor = @get_editor()
    cur_line = editor.getCursorBufferPosition()
    range = [[0,0], editor.getEofBufferPosition()]
    header_regex = _.escapeRegExp(todo_header_string)
    editor.scanInBufferRange new RegExp(header_regex, 'g'), range, (result) ->
      result.stop()
      footer_regex = _.escapeRegExp(footer_string)
      range = [result.range.end, editor.getEofBufferPosition()]
      editor.scanInBufferRange new RegExp(footer_regex, 'g'), range, (footer_result) ->
        footer_result.stop()
        editor.setCursorBufferPosition(footer_result.range.start)
        editor.moveLeft()
        editor.insertNewline()
        editor.moveToBeginningOfLine()
        editor.insertText('  ')
    return true


  add_to_todo: ->
    editor = @get_editor()
    cur_line = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    end_of_line = editor.getCursorBufferPosition()
    editor.setSelectedBufferRange([[cur_line.row,0],end_of_line])
    todo = editor.getSelectedText()
    if !@is_header(todo)
      range = [[0,0], editor.getEofBufferPosition()]
      header_regex = _.escapeRegExp(todo_header_string)
      editor.scanInBufferRange new RegExp(header_regex, 'g'), range, (result) ->
        result.stop()
        footer_regex = _.escapeRegExp(footer_string)
        range = [result.range.end, editor.getEofBufferPosition()]
        editor.scanInBufferRange new RegExp(footer_regex, 'g'), range, (footer_result) ->
          footer_result.stop()
          editor.setCursorBufferPosition(footer_result.range.start)
          editor.moveLeft()
          editor.insertNewline()
          editor.moveToBeginningOfLine()
          todo = todo.replace(/\$\([a-zA-Z0-9_ ]*\)[ ]?/g, '') # Strip out the time spent marker, '$()', since we are repeating
          todo = todo.replace(/(^\s+|\s+$)/g,'') # Trim()
          editor.insertText('  ')
          editor.insertText(todo)
          paste_line = editor.getCursorBufferPosition()
          if paste_line.row < cur_line.row
            editor.setCursorBufferPosition([cur_line.row + 1, 0])
          else
            editor.setCursorBufferPosition([cur_line.row, 0])
      return true
    else
      console.log("Can't move section marker.")
      editor.setCursorBufferPosition(cur_line)
      return false


  close_todo: ->
    date_format = atom.config.get 'gpd.dateFormat'
    closed_time = ("~(" + moment().format(date_format) + ") ")
    return @move_todo_to_section("Closed", closed_time)

  # Create a new note section with boilerplate text in the view supplied
  create_note: (note_time, todo_str) ->
    note_header = "//" + note_time + "//\n"
    note_footer = "//End//\n\n"
    note_boiler_str = (note_header + "  " + todo_str + "\n\n  \n"+ note_footer)
    editor = @get_editor()
    editor.unfoldAll()
    note_boiler_range = editor.getBuffer().insert([0,0], note_boiler_str)
    # Need to convert to array of points because I cannot seem to create a Range
    # object in other parts of the code, and the highlight_note code assumes that
    # note_range is an array of points with note_range[0] being the start
    # and note_range[1] being the end. However, the range object does not
    # guarantee that.
    @highlight_note([note_boiler_range.start, note_boiler_range.end])
    editor.setCursorBufferPosition([note_boiler_range.end.row-3, 4])



  # Fold the other notes, and unfold the selected not so the user can focus
  # on the note they are working on. Assumption that note_range is an array of
  # points with note_range[0] being the start and note_range[1] being the end.
  highlight_note: (note_range) ->
    editor = @get_editor()
    before_note = [[0, 0], [note_range[0].row, 0]]
    after_note = [note_range[1], editor.getBuffer().getEndPosition()]
    editor.setSelectedBufferRanges([before_note, after_note])
    editor.foldSelectedLines()


  # Find a note with the given header_text in the view
  find_note_header: (header_text) ->
    editor = @get_editor()
    me = @
    found = false
    editor.unfoldAll()
    editor.scanInBufferRange new RegExp("//" + header_text + "//", 'g'), [[0,0],editor.getEofBufferPosition()], (result) ->
      result.stop()
      editor.scanInBufferRange new RegExp("//End//", 'g'), [result.range.end,editor.getEofBufferPosition()], (footer_result) ->
        footer_result.stop()
        note_range = [result.range.start, footer_result.range.end]
        me.highlight_note(note_range)
        editor.setCursorBufferPosition([note_range[1].row-1, 0])
        editor.moveToEndOfLine()
        found = true
    return found


  note_exists: (text) ->
    if text.match(note_header_pattern) then return note_header_pattern.exec(text)[0] else return false

  open_note_file: ->
    filename = @get_editor().getBuffer().getUri() + "_Note"
    return atom.workspace.open(filename)


  open_todo: ->
    editor = @get_editor()
    editor.transact ->
      filename = editor.getBuffer().getUri().replace('.GPD_Note','.GPD')
      return atom.workspace.open(filename)

  open_note: ->
    editor = @get_editor()
    cur_pos = editor.getCursorBufferPosition()
    date_format = atom.config.get 'gpd.dateFormat'
    note_time =  moment().format(date_format)
    editor.moveToEndOfLine()
    end_of_line = editor.getCursorBufferPosition()
    editor.selectToBeginningOfLine()
    todo_str = editor.getSelectedText().trim()
    note_text = @note_exists(todo_str)
    if !@is_header(todo_str)
      if note_text
        match = note_header_pattern.exec(note_text)
        inner_note = match[1]
        todo_str_min = todo_str.replace(match[0], "").trim()
        @open_note_file().then =>
          console.log(@find_note_header(inner_note))
          if !@find_note_header(inner_note)
            @create_note(inner_note, todo_str_min)
      else
        editor.moveToEndOfLine()
        editor.insertText(" `(" + note_time + ")")
        @open_note_file().then =>
          @create_note(note_time, todo_str)
    else
      console.log("No notes for headers.")
    editor.setCursorBufferPosition(cur_pos)

  start: ->
    console.log "pomodoro: start"
    restLength = atom.config.get 'gpd.restLengthMinutes'
    editor = @get_editor()
    cur_line = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    end_of_line = editor.getCursorBufferPosition()
    @todo_range = [[cur_line.row,0],end_of_line]
    @filename = editor.getBuffer().getUri()
    editor.setSelectedBufferRange(@todo_range)
    todo = editor.getSelectedText()
    timerObj = @timer
    todo = todo.replace(/\$\([a-zA-Z0-9_/ ]*[\)]?[ ]?/g, '') # Strip out the time spent marker, '$()',
    todo = todo.replace(/\#\([a-zA-Z0-9_\"\., ]*\)[ ]?/g, '') # Strip out the time spent marker, '#()'
    todo = todo.replace(/`\([a-zA-Z0-9_\"\., ]*[\)]?[ ]?/g, '') # Strip out the time spent marker, '`()'
    todo = todo.replace(/(^\s+|\s+$)/g,'') # Trim()
    atom.notifications.addSuccess("🍅 Started: '#{todo}'")
    timerObj.start(todo)
    @todo = todo
    @newTodoTracker()

  newTodoTracker: ->
    editor = @get_editor()
    if editor.getGrammar().scopeName == 'source.GPD'
      range = @todo_range
      found = false
      editor.scanInBufferRange /\$\([a-zA-Z0-9_/ ]*\)?/g, range, (result) ->
        result.stop()
        found = true
        editor.setCursorBufferPosition(result.range.end)
        editor.selectLeft()
        if editor.getSelectedText() != ')'
          editor.moveRight()
          editor.insertText(')')
        editor.moveLeft()
        editor.insertText('O')
      if !found
        editor.setCursorBufferPosition([range[1].row, range[1].column])
        editor.insertText(" $(O)")
      editor.moveToEndOfLine()
      end_of_line = editor.getCursorBufferPosition()
      range = [range[0],end_of_line]
      @todo_range = range

  updateTodoTracker: (text) ->
    range = @todo_range
    editor = @get_editor()
    atom.workspace.open(@filename).then ->
      editor.moveToEndOfLine()
      end_of_line = editor.getCursorBufferPosition()
      range = [range[0],end_of_line]
      found = false
      editor.scanInBufferRange /\$\([a-zA-Z0-9_/ ]*\)?/g, range, (result) ->
        result.stop()
        found = true
        editor.selectLeft()
        if editor.getSelectedText() != ')'
          editor.moveRight()
          editor.insertText(')')
          editor.setCursorBufferPosition([range[1].row, range[1].column])
        else
          editor.setCursorBufferPosition([range[1].row, range[1].column - 1])
        editor.selectLeft()
        selectedChar = editor.getSelectedText()
        if selectedChar == '/'
          editor.moveRight()
        else if selectedChar == ')'
          editor.moveLeft()
        editor.insertText(text)
      if !found
        editor.setCursorBufferPosition([range[1].row, range[1].column])
        editor.insertText(" $(" + text + ")")
      editor.moveToEndOfLine()
      end_of_line = editor.getCursorBufferPosition()
      range = [range[0],end_of_line]
    @todo_range = range


  abort: ->
    console.log "pomodoro: abort"
    @timer.abort()
    @updateTodoTracker("/")
    atom.notifications.addWarning("🍅 Aborted #{@todo}")
    @pomodoro_state = "ABORTED"

  finish: ->
    console.log "pomodoro: finish"
    atom.beep()
    atom.focus()
    atom.notifications.addSuccess("🍅 Finished #{@todo}")
    @timer.finish()
    @updateTodoTracker("X")
    @pomodoro_state = "FINISHED"

  start_rest: ->
    console.log "pomodoro: start_rest"
    atom.beep()
    atom.focus()
    atom.notifications.addSuccess("🍅 #{@todo} Work Completed. Start Resting.")
    @timer.start_rest()

  exec: (path) ->
    if path
      exec path, (err, stdout, stderr) ->
        if stderr
          console.log stderr
        console.log stdout

  deactivate: ->
    @view?.destroy()
    @view = null
