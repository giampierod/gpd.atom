###
Copyright 2014 Giampiero De Ciantis. The license text can be found in the
`LICENSE` file provided with this project.'

Description:
  All logic for commands in gpd.atom. These commands can create, move, complete,
  and repeat GPD todos. Also commands for toggling the Notes view.
###

_ = require 'underscore-plus'
{CompositeDisposable, Range, Point, Fold} = require 'atom'
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
      default: "DD/MM/YY hh:mm"

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
      'gpd:narrow-to-section': => @narrowToSection()
      'gpd:unnarrow': => @unnarrow()
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

  narrowToSection: ->
    editor = @getEditor()
    scopeName = editor.getGrammar().scopeName
    if scopeName == 'source.gpd' || scopeName == 'source.gpd_note'
      editor.transact =>
        @foldAroundSection()

  unnarrow: ->
    editor = @getEditor()
    editor.transact =>
      editor.unfoldAll()
      editor.scrollToBufferPosition(editor.getCursorBufferPosition())

  attempt: (fn) ->
    editor = @getEditor()
    if editor.getGrammar().scopeName == 'source.gpd'
      editor.transact =>
        if !fn.call(@) then editor.abortTransaction()

  selectTodo: -> @attempt(-> @moveTodoToSection 'Todo')

  doneTodo: -> @attempt(@closeTodo)

  newTodo: ->
    editor = @getEditor()
    editor.transact =>
      switch editor.getGrammar().scopeName
        when 'source.gpd_note' then @makeTodoFromNoteLine()
        when 'source.gpd' then @createTodo()

  doneTodoAndRepeat: ->
    @attempt( ->
      closedTime = ("~(#{moment().format(atom.config.get('gpd.dateFormat'))}) ")
      @copyTodoToSection('Closed', null, closedTime)
      @removeTag('$')
      @moveTodoToSection('Backlog', 'bottom')
    )

  isHeader: (text) ->
    headerPattern = new RegExp('//(.*)//')
    headerPattern.test(text)

  selectCurrentLine: (editor) ->
    origPos = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    editor.selectToBeginningOfLine()
    todo = editor.getSelectedText()
    return { 'text': todo, 'position': origPos}

  moveTodoToSection: (section, bottom, prefix) ->
    if @copyTodoToSection(section, bottom, prefix)
      @getEditor().deleteLine()

  copyTodoToSection: (section, bottom, prefix) ->
    editor = @getEditor()
    line = @selectCurrentLine(editor)
    if !@isHeader(line.text)
      if bottom
        @moveCursorToSection(editor, section, 'footer')
        editor.moveLeft()
      else
        @moveCursorToSection(editor, section)
      editor.insertNewline()
      editor.moveToBeginningOfLine()
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
    else
      atom.notifications.addError("Headers and footers not allowed to be moved.")
      return false

  insertNewTodo: (section, bottom, text) ->
    editor = @getEditor()
    if !@isHeader(text)
      if bottom
        @moveCursorToSection(editor, section, 'footer')
        editor.moveLeft()
      else
        @moveCursorToSection(editor, section)
      editor.insertNewline()
      editor.moveToBeginningOfLine()
      editor.indentSelectedRows()
      editor.insertText(text)
      pasteLine = editor.getCursorBufferPosition()
      return true
    else
      atom.notifications.addError("Headers and footers not allowed to be added as Todos.")
      return false

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

  removeTag: (tagIndicator) ->
    editor = @getEditor()
    line = @selectCurrentLine(editor)
    regex = _.escapeRegExp(tagIndicator) + "\\(.*?\\)[ ]?"
    lineWithoutTag = line.text.replace(new RegExp(regex, 'g'), '')
    editor.insertText(lineWithoutTag)
    return true

  addToBacklog: -> @copyTodoToSection('Backlog', 'bottom')

  createTodo: ->
    editor = @getEditor()
    @moveCursorToSection(editor, 'Backlog', 'footer')
    editor.insertNewlineAbove()
    return true

  closeTodo: ->
    closedTime = ("~(#{moment().format(atom.config.get('gpd.dateFormat'))}) ")
    return @moveTodoToSection("Closed", null, closedTime)

  # Create a new note section with boilerplate text in the view supplied
  createNote: (noteHeaderText, todoStr) ->
    noteHeader = "//" + noteHeaderText + "//\n"
    noteFooter = "//End//"
    noteBoilerStr = (noteHeader + "  " + todoStr + "\n\n  \n"+ noteFooter)
    editor = @getEditor()
    @unhideNotes()
    noteBoilerRange = editor.getBuffer().insert([0,0], noteBoilerStr)
    editor.getBuffer().insert(noteBoilerRange.end, "\n\n")
    return new Range(noteBoilerRange.start, noteBoilerRange.end)

  # Fold and 'eventually' hide the other notes, and unfold the selected note so
  # the user can focus on the note they are working on. NoteRange must be an
  # actual Range object (no arrays of points or arrays of arrays of coordinates)
  # TODO: Implement Narrow function into Atom so that I don't have to fold
  highlightNote: (noteRange) ->
    editor = @getEditor()
    eof = editor.getBuffer().getEndPosition()
    afterNote = [[noteRange.end.row + 1, 0], [eof.row, eof.column]]
    curPos = editor.getCursorBufferPosition()
    if noteRange.start.row > 0
      beforeNote = [[0, 0], [noteRange.start.row - 1, 0]]
      editor.setSelectedBufferRanges([beforeNote, afterNote])
    else
      editor.setSelectedBufferRanges([afterNote])
    editor.foldSelectedLines()
    editor.setCursorBufferPosition(curPos)


  unhideNotes: ->
    editor = @getEditor()
    editor.unfoldAll()


  foldAroundSection: () ->
    console.log("foldAroundSection called")
    headerFoundResult = @findThisHeader()
    if headerFoundResult.found
      console.log("Header Found")
      sectionFoundResult = @getSectionForHeader(headerFoundResult.text)
      if sectionFoundResult.found
        console.log("Section Range Found")
        @highlightNote(sectionFoundResult.range)


  # Find a note with the given headerText in the view
  getSectionForHeader: (headerText) ->
    editor = @getEditor()
    me = @
    searchResult = {found: false, range: null}
    @unhideNotes()
    editor.scanInBufferRange new RegExp("//#{headerText}//", 'g'), [[0,0],editor.getEofBufferPosition()], (result) ->
      result.stop()
      editor.scanInBufferRange new RegExp("//End//", 'g'), [result.range.end,editor.getEofBufferPosition()], (footerResult) ->
        footerResult.stop()
        noteRange = new Range(result.range.start, footerResult.range.end)
        searchResult.found = true
        searchResult.range = noteRange
    return searchResult


  # Find the header in the current note/section
  findThisHeader: () ->
    editor = @getEditor()
    me = @
    searchResult = {found: false, text: null}
    headerRegex = new RegExp("//(.*)//", 'g')
    editor.backwardsScanInBufferRange headerRegex, [[0,0],editor.getCursorBufferPosition()], (result) ->
      result.stop()
      searchResult.found = true
      searchResult.text = result.match[1]
    return searchResult

  noteExists: (text) ->
    if text.match(noteHeaderPattern) then return noteHeaderPattern.exec(text)[0] else return false

  openNoteFile: ->
    filename = @getEditor().getBuffer().getUri() + "_note"
    return atom.workspace.open(filename)

  openTodo: ->
    filename = @getEditor().getBuffer().getUri().replace(/_note/i,'')
    return atom.workspace.open(filename)


  makeTodoFromNoteLine: ->
    editor = @getEditor()
    curPos = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    endOfLine = editor.getCursorBufferPosition()
    editor.selectToBeginningOfLine()
    todoStr = editor.getSelectedText().trim().replace(/^\W/g,"").trim()
    headerSearchResult = @findThisHeader()
    if headerSearchResult.found
      todoStr = todoStr + (" `(#{headerSearchResult.text})")
    if !@isHeader(todoStr)
      @openTodo().then =>
        console.log("Todo Opened")
        console.log(todoStr)
        @insertNewTodo("Backlog", "bottom", todoStr)
    else
      atom.notifications.addError("Can't create Todo From Header.")
    editor.setCursorBufferPosition(curPos)

  # Finds the note matching the Todo or creates a new one
  openNote: ->
    editor = @getEditor()
    curPos = editor.getCursorBufferPosition()
    noteTime =  moment().format("YYYY.MM.DD.hh.mm")
    editor.moveToEndOfLine()
    endOfLine = editor.getCursorBufferPosition()
    editor.selectToBeginningOfLine()
    todoStr = editor.getSelectedText().trim()
    noteText = @noteExists(todoStr)
    if !@isHeader(todoStr)
      noteRange = new Range(0,0)
      if noteText
        match = noteHeaderPattern.exec(noteText)
        innerNote = match[1]
        todoStrMin = todoStr.replace(match[0], "").trim()
        @openNoteFile().then =>
          noteSearchResult = @getSectionForHeader(innerNote)
          if noteSearchResult.found
            noteRange = noteSearchResult.range
          else
            noteRange = @createNote(innerNote, todoStrMin)
          @highlightNote(noteRange)
          @getEditor().setCursorBufferPosition([noteRange.end.row-1, Infinity])
      else
        editor.moveToEndOfLine()
        if !editor.getLastCursor().isSurroundedByWhitespace()
          editor.insertText(" ")
        editor.insertText("`(#{noteTime})")
        @openNoteFile().then =>
          noteRange = @createNote(noteTime, todoStr)
          @highlightNote(noteRange)
          @getEditor().setCursorBufferPosition([noteRange.end.row-1, Infinity])
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
