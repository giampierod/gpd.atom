###
Copyright 2015 Giampiero De Ciantis

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Filename: /lib/todos.coffee
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


todoHeaderString = '//Todo//'
closedHeaderString = '//Closed//'
todayHeaderString = '//Today//'
footerString = '//End//'
noteHeaderPattern = /`\(([a-zA-Z0-9_\"\., ]*)\)/
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

  activate: (state) ->
    atom.static.variables.pomodoro = "atom://gpd/resources/pomodoro.png"
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:new-todo': => @newTodo()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:select-todo': => @selectTodo()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:done-todo': => @doneTodo()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:done-todo-and-repeat': => @doneTodoAndRepeat()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:toggle-note': =>
      editor = atom.workspace.getActiveTextEditor()
      editor.transact =>
        if editor.getGrammar().scopeName == 'source.GPD_Note'
          @openTodo()
        else if editor.getGrammar().scopeName == 'source.GPD'
          @openNote()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:start-timer': => @start()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:abort-timer': => @abort()
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpd:toggle-pomodoro': => @togglePomodoro()
    @timer = new PomodoroTimer()
    @view = new PomodoroView(@timer)
    @timer.on 'finished', => @finish()
    @timer.on 'rest', => @startRest()
    @timer.on 'start', =>
      @pomodoroState = "STARTED"

  consumeStatusBar: (statusBar) ->
    @statusBarTile = statusBar.addLeftTile(item: @view, priority: 100)

  togglePomodoro: ->
    if @pomodoroState == "STARTED"
      @abort()
    else
      @start()

  selectTodo: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor.getGrammar().scopeName == 'source.GPD'
    editor.transact =>
      if !@moveTodoToSection('Today')
        editor.abortTransaction()

  doneTodo: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor.getGrammar().scopeName == 'source.GPD'
    editor.transact =>
      if !@closeTodo()
        editor.abortTransaction()

  newTodo: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor.getGrammar().scopeName == 'source.GPD'
    editor.transact =>
      if !@createTodo()
        editor.abortTransaction()

  doneTodoAndRepeat: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor.getGrammar().scopeName == 'source.GPD'
    editor.transact =>
      if !@addToTodo() || !@closeTodo()
        editor.abortTransaction()

  isHeader: (text) ->
    headerPattern = new RegExp('//(.*)//')
    headerPattern.test(text)

  moveTodoToSection: (section, prefix) ->
    editor = atom.workspace.getActiveTextEditor()
    curLine = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    endOfLine = editor.getCursorBufferPosition()
    editor.setSelectedBufferRange([[curLine.row,0],endOfLine])
    todo = editor.getSelectedText()
    todo = todo.replace(/(^\s+|\s+$)/g,'')
    if !@isHeader(editor.getSelectedText())
      editor.delete()
      editor.delete()
      range = [[0,0], editor.getEofBufferPosition()]
      headerRegex = _.escapeRegExp('//' + section + '//')
      editor.scanInBufferRange new RegExp(headerRegex, 'g'), range, (result) ->
        result.stop()
        editor.setCursorBufferPosition(result.range.end)
        editor.insertNewline()
        editor.moveToBeginningOfLine()
        editor.insertText('  ')
        if typeof prefix != 'undefined'
          editor.insertText(prefix)
        editor.insertText(todo)
        pasteLine = editor.getCursorBufferPosition()
        if pasteLine.row < curLine.row
          editor.setCursorBufferPosition([curLine.row + 1, 0])
        else
          editor.setCursorBufferPosition([curLine.row, 0])
      return true
    else
      console.log("Can't move section marker")
      editor.setCursorBufferPosition(curLine)
      return false

  createTodo: ->
    console.log("Creating todo")
    editor = atom.workspace.getActiveTextEditor()
    curLine = editor.getCursorBufferPosition()
    range = [[0,0], editor.getEofBufferPosition()]
    headerRegex = _.escapeRegExp(todoHeaderString)
    editor.scanInBufferRange new RegExp(headerRegex, 'g'), range, (result) ->
      result.stop()
      footerRegex = _.escapeRegExp(footerString)
      range = [result.range.end, editor.getEofBufferPosition()]
      editor.scanInBufferRange new RegExp(footerRegex, 'g'), range, (footerResult) ->
        footerResult.stop()
        editor.setCursorBufferPosition(footerResult.range.start)
        editor.moveLeft()
        editor.insertNewline()
        editor.moveToBeginningOfLine()
        editor.insertText('  ')
    return true


  addToTodo: ->
    editor = atom.workspace.getActiveTextEditor()
    curLine = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    endOfLine = editor.getCursorBufferPosition()
    editor.setSelectedBufferRange([[curLine.row,0],endOfLine])
    todo = editor.getSelectedText()
    if !@isHeader(todo)
      range = [[0,0], editor.getEofBufferPosition()]
      headerRegex = _.escapeRegExp(todoHeaderString)
      editor.scanInBufferRange new RegExp(headerRegex, 'g'), range, (result) ->
        result.stop()
        footerRegex = _.escapeRegExp(footerString)
        range = [result.range.end, editor.getEofBufferPosition()]
        editor.scanInBufferRange new RegExp(footerRegex, 'g'), range, (footerResult) ->
          footerResult.stop()
          editor.setCursorBufferPosition(footerResult.range.start)
          editor.moveLeft()
          editor.insertNewline()
          editor.moveToBeginningOfLine()
          todo = todo.replace(/\$\([a-zA-Z0-9_ ]*\)[ ]?/g, '') # Strip out the time spent marker, '$()', since we are repeating
          todo = todo.replace(/(^\s+|\s+$)/g,'') # Trim()
          editor.insertText('  ')
          editor.insertText(todo)
          pasteLine = editor.getCursorBufferPosition()
          if pasteLine.row < curLine.row
            editor.setCursorBufferPosition([curLine.row + 1, 0])
          else
            editor.setCursorBufferPosition([curLine.row, 0])
      return true
    else
      console.log("Can't move section marker.")
      editor.setCursorBufferPosition(curLine)
      return false


  closeTodo: ->
    closedTime = ("~(" + moment().format("DD/MM/YY hh:mm") + ") ")
    return @moveTodoToSection("Closed", closedTime)

  # Create a new note section with boilerplate text in the view supplied
  createNote: (noteTime, todoStr) ->
    noteHeader = "//" + noteTime + "//\n"
    noteFooter = "//End//\n\n"
    noteBoilerStr = (noteHeader + "  " + todoStr + "\n\n  \n"+ noteFooter)
    editor = atom.workspace.getActiveTextEditor()
    editor.unfoldAll()
    noteBoilerRange = editor.getBuffer().insert([0,0], noteBoilerStr)
    # Need to convert to array of points because I cannot seem to create a Range
    # object in other parts of the code, and the highlightNote code assumes that
    # noteRange is an array of points with noteRange[0] being the start
    # and noteRange[1] being the end. However, the range object does not
    # guarantee that.
    @highlightNote([noteBoilerRange.start, noteBoilerRange.end])
    editor.setCursorBufferPosition([noteBoilerRange.end.row-3, 4])



  # Fold the other notes, and unfold the selected not so the user can focus
  # on the note they are working on. Assumption that noteRange is an array of
  # points with noteRange[0] being the start and noteRange[1] being the end.
  highlightNote: (noteRange) ->
    editor = atom.workspace.getActiveTextEditor()
    beforeNote = [[0, 0], [noteRange[0].row, 0]]
    afterNote = [noteRange[1], editor.getBuffer().getEndPosition()]
    editor.setSelectedBufferRanges([beforeNote, afterNote])
    editor.foldSelectedLines()


  # Find a note with the given headerText in the view
  findNoteHeader: (headerText) ->
    editor = atom.workspace.getActiveTextEditor()
    me = @
    found = false
    editor.unfoldAll()
    editor.scanInBufferRange new RegExp("//" + headerText + "//", 'g'), [[0,0],editor.getEofBufferPosition()], (result) ->
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
    filename = atom.workspace.getActiveTextEditor().getBuffer().getUri() + "_Note"
    return atom.workspace.open(filename)


  openTodo: ->
    editor = atom.workspace.getActiveTextEditor()
    editor.transact ->
      filename = atom.workspace.getActiveTextEditor().getBuffer().getUri().replace('.GPD_Note','.GPD')
      return atom.workspace.open(filename)

  openNote: ->
    editor = atom.workspace.getActiveTextEditor()
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
        editor.insertText(" `(" + noteTime + ")")
        @openNoteFile().then =>
          @createNote(noteTime, todoStr)
    else
      console.log("No notes for headers.")
    editor.setCursorBufferPosition(curPos)

  start: ->
    console.log "pomodoro: start"
    restLength = atom.config.get 'gpd.restLengthMinutes'
    editor = atom.workspace.getActiveTextEditor()
    curLine = editor.getCursorBufferPosition()
    editor.moveToEndOfLine()
    endOfLine = editor.getCursorBufferPosition()
    @todoRange = [[curLine.row,0],endOfLine]
    @filename = atom.workspace.getActiveTextEditor().getBuffer().getUri()
    editor.setSelectedBufferRange(@todoRange)
    todo = editor.getSelectedText()
    timerObj = @timer
    todo = todo.replace(/\$\([a-zA-Z0-9_/ ]*[\)]?[ ]?/g, '') # Strip out the time spent marker, '$()',
    todo = todo.replace(/\#\([a-zA-Z0-9_\"\., ]*\)[ ]?/g, '') # Strip out the time spent marker, '#()'
    todo = todo.replace(/`\([a-zA-Z0-9_\"\., ]*[\)]?[ ]?/g, '') # Strip out the time spent marker, '`()'
    todo = todo.replace(/(^\s+|\s+$)/g,'') # Trim()
    atom.notifications.addSuccess("Started: '#{todo}'", {icon: "pomodoro"})
    timerObj.start(todo)
    @todo = todo
    @newTodoTracker()

  newTodoTracker: ->
    editor = atom.workspace.getActiveTextEditor()
    if editor.getGrammar().scopeName == 'source.GPD'
      range = @todoRange
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
      endOfLine = editor.getCursorBufferPosition()
      range = [range[0],endOfLine]
      @todoRange = range

  updateTodoTracker: (text) ->
    range = @todoRange
    atom.workspace.open(@filename).then ->
      editor = atom.workspace.getActiveTextEditor()
      editor.moveToEndOfLine()
      endOfLine = editor.getCursorBufferPosition()
      range = [range[0],endOfLine]
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
      endOfLine = editor.getCursorBufferPosition()
      range = [range[0],endOfLine]
    @todoRange = range


  abort: ->
    console.log "pomodoro: abort"
    @timer.abort()
    @updateTodoTracker("/")
    atom.notifications.addWarning("Aborted #{@todo}", {icon: "circle-slash"})
    @pomodoroState = "ABORTED"

  finish: ->
    console.log "pomodoro: finish"
    atom.beep()
    atom.focus()
    atom.notifications.addSuccess("Finished #{@todo}")
    @timer.finish()
    @updateTodoTracker("X")
    @pomodoroState = "FINISHED"

  startRest: ->
    console.log "pomodoro: startRest"
    atom.beep()
    atom.focus()
    atom.notifications.addSuccess("#{@todo} Work Completed. Start Resting.", {icon: "clock"})
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
