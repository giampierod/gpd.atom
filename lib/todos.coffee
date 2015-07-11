###
Copyright 2014 Giampiero De Ciantis. The license text can be found in the
`LICENSE` file provided with this project.'

Description:
  All logic for commands in gpd.atom. These commands can create, move, complete,
  and repeat GPD todos. Also commands for toggling the Notes view.
###

_ = require 'underscore-plus'
{CompositeDisposable, Range} = require 'atom'
{exec, child} = require 'child_process'
moment = require 'moment'
PomodoroTimer = require './pomodoro-timer'
PomodoroView = require './pomodoro-view'

todoHeaderString = '//Backlog//'
closedHeaderString = '//Closed//'
todayHeaderString = '//Todo//'
footerString = '//End//'
noteHeaderPattern = /`\(([a-zA-Z0-9_\"\., ]*)\)/
playSounds: false

module.exports =
  config:
    pomodoroLengthMinutes:
      type: 'integer'
      default: '25'
      minimum: '1'
    shortRestLengthMinutes:
      type: 'integer'
      default: '3'
      minimum: '1'
    longRestLengthMinutes:
      type: 'integer'
      default: '15'
      minimum: '5'
    dateFormat:
      type: 'string'
      default: "YYYY-MM-DD hh:mm"

  activate: (state) ->
    bindings = {
      'gpd:new-todo': => @newTodo()
      'gpd:select-todo': => @selectTodo()
      'gpd:done-todo': => @doneTodo()
      'gpd:done-todo-and-repeat': => @doneTodoAndRepeat()
      'gpd:toggle-note': => @toggleNote()
      'gpd:start_timer': => @start()
      'gpd:abort_timer': => @abort()
      'gpd:toggle-pomodoro': => @togglePomodoro()
    }

    subscriptions = atom.commands.add 'atom-workspace', bindings
    @timer = new PomodoroTimer()
    @view = new PomodoroView(@timer)
    @timer.on 'finished', => @finish()
    @timer.on 'rest', => @startRest()
    @timer.on 'start', =>
      @pomodoroState = "STARTED"

  getEditor: -> atom.workspace.getActiveTextEditor()

  consumeStatusBar: (statusBar) ->
    @statusBarTile = statusBar.addLeftTile(item: @view, priority: 100)

  togglePomodoro: ->
    if @pomodoroState == "STARTED"
      @abort()
    else
      @start()

  toggleNote: ->
    editor = @getEditor()
    editor.transact =>
      switch editor.getGrammar().scopeName
        when 'source.gpd_note' then @openTodo()
        when 'source.gpd' then @openNote()

  attempt: (fn) ->
    editor = @getEditor()
    if editor.getGrammar().scopeName == 'source.gpd'
      editor.transact =>
        if !fn.call(@) then editor.abortTransaction()

  selectTodo: -> @attempt(-> @moveTodoToTopOfSection 'Todo')

  doneTodo: -> @attempt(@closeTodo)

  newTodo: -> @attempt(@createTodo)

  doneTodoAndRepeat: -> @attempt(-> @addToBacklog() && @closeTodo())

  isHeader: (text) ->
    headerPattern = new RegExp('//(.*)//')
    headerPattern.test(text)

  deleteLine: ->
    editor = @getEditor()
    editor.moveToEndOfLine()
    editor.selectToBeginningOfLine()
    editor.delete()  # delete line content
    editor.delete()  # delete newline

  selectCurrentLine: (editor) ->
    origPos = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    editor.selectToBeginningOfLine()
    todo = editor.getSelectedText()
    return { 'text': todo, 'position': origPos}

  moveTodoToTopOfSection: (section, prefix) -> @moveTodoToSection(section, false, prefix)
  moveTodoToBottomOfSection: (section, prefix) -> @moveTodoToSection(section, true, prefix)

  moveTodoToSection: (section, bottom, prefix) ->
    editor = @getEditor()
    line = @selectCurrentLine(editor)
    if !@isHeader(line.text)
      @deleteLine()
      if bottom
        @moveCursorToSection(editor, section, 'footer')
        editor.moveLeft()
      else
        @moveCursorToSection(editor, section)
      editor.insertNewline()
      editor.insertText(line.text)
      if prefix  # Unless prefix is undefined or empty in any way:
        editor.moveToFirstCharacterOfLine()
        editor.insertText(prefix)
      pasteLine = editor.getCursorBufferPosition()
      # If we insert a line above, text will be pushed down 1 line, meaning
      # line.position will be off. Account for that:
      linesInsertedAbove = if pasteLine.row < line.position.row then 1 else 0
      editor.setCursorBufferPosition([line.position.row + linesInsertedAbove, line.position.column])
      return true

  moveCursorToSection: (editor, section, footer) ->
    headerRegex = _.escapeRegExp('//' + section + '//')
    moveCursorToEnd = @moveCursorToEnd  # `editor.scan` rebinds `@`
    editor.scan new RegExp(headerRegex, 'g'), (result) ->
      result.stop()
      if footer
        moveCursorToEnd(editor, result.range.end)
      else
        editor.setCursorBufferPosition(result.range.end)

  moveCursorToEnd: (editor, position) ->
    footerRegex = _.escapeRegExp(footerString)
    range = [position, editor.getEofBufferPosition()]
    editor.scanInBufferRange new RegExp(footerRegex, 'g'), range, (result) ->
      result.stop()
      editor.setCursorBufferPosition(result.range.start)

  addToBacklog: -> @moveTodoToBottomOfSection('Backlog')

  createTodo: ->
    editor = @getEditor()
    @moveCursorToSection(editor, 'Backlog', 'footer')
    editor.insertNewlineAbove()
    return true

  closeTodo: ->
    closedTime = ("~(#{moment().format(atom.config.get('gpd.dateFormat'))}) ")
    return @moveTodoToTopOfSection("Closed", closedTime)

  # Create a new note section with boilerplate text in the view supplied
  createNote: (noteTime, todoStr) ->
    noteHeader = "//" + noteTime + "//\n"
    noteFooter = "//End//\n\n"
    noteBoilerStr = (noteHeader + "  " + todoStr + "\n\n  \n"+ noteFooter)
    editor = @getEditor()
    editor.unfoldAll()
    noteBoilerRange = editor.getBuffer().insert([0,0], noteBoilerStr)
    @highlightNote([noteBoilerRange.start, noteBoilerRange.end])
    editor.setCursorBufferPosition([noteBoilerRange.end.row-3, 4])



  # Fold the other notes, and unfold the selected not so the user can focus
  # on the note they are working on. Assumption that noteRange is an array of
  # points with noteRange[0] being the start and noteRange[1] being the end.
  highlightNote: (noteRange) ->
    editor = @getEditor()
    beforeNote = [[0, 0], [noteRange[0].row, 0]]
    afterNote = [noteRange[1], editor.getBuffer().getEndPosition()]
    editor.setSelectedBufferRanges([beforeNote, afterNote])
    editor.foldSelectedLines()


  # Find a note with the given headerText in the view
  findNoteHeader: (headerText) ->
    editor = @getEditor()
    me = @
    found = false
    editor.unfoldAll()
    editor.scanInBufferRange new RegExp("//#{headerText}//", 'g'), [[0,0],editor.getEofBufferPosition()], (result) ->
      result.stop()
      editor.scanInBufferRange new RegExp("//End//", 'g'), [result.range.end,editor.getEofBufferPosition()], (footerResult) ->
        footerResult.stop()
        noteRange = [result.range.start, footerResult.range.end]
        me.highlightNote(noteRange)
        editor.setCursorBufferPosition([noteRange[1].row-1, 0])
        editor.moveToEndOfLine()
        found = true
    return found


  noteExists: (text) ->
    if text.match(noteHeaderPattern) then return noteHeaderPattern.exec(text)[0] else return false

  openNoteFile: ->
    filename = @getEditor().getBuffer().getUri() + "_note"
    return atom.workspace.open(filename)

  openTodo: ->
    console.log("Open Todo")
    filename = @getEditor().getBuffer().getUri().replace('.gpd_note','.gpd')
    return atom.workspace.open(filename)

  openNote: ->
    console.log("Open Note")
    editor = @getEditor()
    curPos = editor.getCursorBufferPosition()
    noteTime =  moment().format("YYYY.MM.DD.hh.mm")
    editor.moveToEndOfLine()
    endOfLine = editor.getCursorBufferPosition()
    editor.selectToBeginningOfLine()
    todoStr = editor.getSelectedText().trim()
    noteText = @noteExists(todoStr)
    if !@isHeader(todoStr)
      if noteText
        match = noteHeaderPattern.exec(noteText)
        innerNote = match[1]
        todoStrMin = todoStr.replace(match[0], "").trim()
        @openNoteFile().then =>
          console.log(@findNoteHeader(innerNote))
          if !@findNoteHeader(innerNote)
            @createNote(innerNote, todoStrMin)
      else
        editor.moveToEndOfLine()
        editor.insertText(" `(#{noteTime})")
        @openNoteFile().then =>
          @createNote(noteTime, todoStr)
    else
      atom.notifications.addError("No notes allowed for headers.")
    editor.setCursorBufferPosition(curPos)

  start: ->
    restLength = atom.config.get 'gpd.restLengthMinutes'
    editor = @getEditor()
    curLine = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    endOfLine = editor.getCursorBufferPosition()
    todoRange = [[curLine.row,0],endOfLine]
    editor.setSelectedBufferRange(todoRange)
    todo = editor.getSelectedText()
    if !@isHeader(todo)
      console.log "pomodoro: start"
      @todoMarker = editor.markBufferRange(todoRange, invalidate: 'never')
      @filename = @getEditor().getBuffer().getUri()
      timerObj = @timer
      todo = todo.replace(/\$\([a-zA-Z0-9_/ ]*[\)]?[ ]?/g, '') # Strip out the time spent marker, '$()',
      todo = todo.replace(/\#\([a-zA-Z0-9_\"\., ]*\)[ ]?/g, '') # Strip out the time spent marker, '#()'
      todo = todo.replace(/`\([a-zA-Z0-9_\"\., ]*[\)]?[ ]?/g, '') # Strip out the time spent marker, '`()'
      todo = todo.replace(/(^\s+|\s+$)/g,'') # Trim()
      atom.notifications.addSuccess("Started: '#{todo}'", {icon: "clock"})
      timerObj.start(todo)
      @todo = todo
      @newTodoTracker()
    else
      atom.notifications.addError("No pomodoros allowed for headers.")

  newTodoTracker: ->
    editor = @getEditor()
    if editor.getGrammar().scopeName == 'source.gpd'
      range = @todoMarker.getBufferRange()
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
        editor.setCursorBufferPosition(range.end)
        editor.insertText(" $(O)")
      editor.moveToEndOfLine()
      endOfLine = editor.getCursorBufferPosition()
      range = [range.start,endOfLine]
      @todoMarker.destroy()
      @todoMarker = editor.markBufferRange(range, invalidate: 'never')

  updateTodoTracker: (text) ->
    console.log("updated todo tracker")
    range = @todoMarker.getBufferRange()
    me = @
    atom.workspace.open(@filename).then ->
      editor = me.getEditor()
      console.log(editor)
      editor.setCursorBufferPosition(range.start)
      editor.moveToEndOfLine()
      endOfLine = editor.getCursorBufferPosition()
      range = new Range(range.start,endOfLine)
      console.log(range)
      found = false
      editor.scanInBufferRange /\$\([a-zA-Z0-9_/ ]*\)?/g, range, (result) ->
        result.stop()
        console.log("tracker found")
        found = true
        editor.selectLeft()
        if editor.getSelectedText() != ')'
          editor.moveRight()
          editor.insertText(')')
          editor.setCursorBufferPosition(endOfLine)
        else
          editor.moveLeft()
          console.log editor.getCursorBufferPosition()
        editor.selectLeft()
        selectedChar = editor.getSelectedText()
        if selectedChar == '/'
          editor.moveRight()
        else if selectedChar == ')'
          editor.moveLeft()
        editor.insertText(text)
      if !found
        editor.setCursorBufferPosition(endOfLine)
        editor.insertText(" $(" + text + ")")
      editor.moveToEndOfLine()
      endOfLine = editor.getCursorBufferPosition()
      range = [range.start,endOfLine]
      @todoMarker.destroy()
      @todoMarker = editor.markBufferRange(range, invalidate: 'never')

  abort: ->
    @timer.abort()
    @updateTodoTracker("/")
    atom.notifications.addWarning("Aborted: '#{@todo}'", {icon: "circle-slash"})
    @pomodoroState = "ABORTED"

  finish: ->
    atom.beep()
    atom.focus()
    atom.notifications.addSuccess("Finished: '#{@todo}'")
    @timer.finish()
    @updateTodoTracker("X")
    @pomodoroState = "FINISHED"

  startRest: ->
    atom.beep()
    atom.focus()
    atom.notifications.addSuccess("'#{@todo}' Work Completed. Start Resting.", {icon: "clock"})
    @timer.startRest()

  exec: (path) ->
    if path
      exec path, (err, stdout, stderr) ->
        if stderr
          console.log stderr
        console.log stdout

  deactivate: ->
    @view?.destroy()
    @view = null
