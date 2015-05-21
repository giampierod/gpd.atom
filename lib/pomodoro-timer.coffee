'Copyright (c) 2014 Yoshiori SHOJI. The license text can be found in the
`LICENSE_SHOJI` file provided with this project.'

events = require 'events'

module.exports =
class PomodoroTimer extends events.EventEmitter

  start: (text) ->
    task_length = atom.config.get 'gpd.pomodoroLengthMinutes'
    task_time = task_length * 60 * 1000
    @emit 'start'
    @startTime = new Date()
    @text = text
    @timer = setInterval ( => @step(task_time,"TASK") ), 1000

  abort: ->
    @status = "Aborted (#{@text})"
    @stop()

  finish: ->
    @status = "Finished (#{@text})"
    @stop()

  start_rest: ->
    rest_length = atom.config.get 'gpd.restLengthMinutes'
    rest_time = rest_length * 60 * 1000
    @status = "Rest"
    @stop()
    @startTime = new Date()
    @timer = setInterval ( => @step(rest_time,"REST") ), 1000

  stop: ->
    clearTimeout @timer
    @updateCallback(@status)

  step: (time_length, type) ->
    time = (time_length - (new Date() - @startTime)) / 1000
    rest = ""
    if type == "REST"
      rest = "Rest for "
    if time <= 0 & type == "TASK"
      @emit 'rest'
    else if time <= 0 & type == "REST"
      @emit 'finished'
    else if time > 0
      min = @zeroPadding(Math.floor(time / 60))
      sec = @zeroPadding(Math.floor(time % 60))
      @status = "#{min}:#{sec} #{rest}#{@text}"
      @updateCallback(@status)

  zeroPadding: (num) ->
    ("0" + num).slice(-2)

  setUpdateCallback: (fn) ->
    @updateCallback = fn
