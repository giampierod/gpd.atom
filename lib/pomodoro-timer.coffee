'Copyright (c) 2014 Yoshiori SHOJI. The license text can be found in the
`LICENSE_SHOJI` file provided with this project.'

events = require 'events'

module.exports =
class PomodoroTimer extends events.EventEmitter

  constructor: ->
    @ticktack = new Audio(require("../resources/ticktack").data())
    @bell = new Audio(require("../resources/bell").data())
    @funk = new Audio(require("../resources/funk").data())
    @ticktack.addEventListener('timeupdate', @loop, false)
    @successCount = 0

  # With a tick tock timer on a loop, it needs to be a little more seamless than
  # your average html5 audio element .loop() method.
  # Thus reinventing the wheel is necessary here.
  loop: ->
    buffer = .27 # Magic number found by playing and listening.
    if this.currentTime > this.duration - buffer
      this.currentTime = 0
      this.play()


  start: (text) ->
    @ticktack.play()
    taskLength = atom.config.get 'gpd.pomodoroLengthMinutes'
    taskTime = taskLength * 60 * 1000
    @emit 'start'
    @startTime = new Date()
    @text = text
    @timer = setInterval ( => @step(taskTime,"TASK") ), 1000

  abort: ->
    @status = "Aborted: '#{@text}'"
    @stop()
    @funk.play()

  finish: ->
    @status = "Finished: '#{@text}'"
    @stop()
    @bell.play()


  startRest: ->
    restLength = atom.config.get 'gpd.shortRestLengthMinutes'
    @successCount++
    if @successCount %% 4 == 0
      restLength = atom.config.get 'gpd.longRestLengthMinutes'
    restTime = restLength * 60 * 1000
    @status = "Rest"
    @stop()
    @bell.play()
    @startTime = new Date()
    @timer = setInterval ( => @step(restTime,"REST") ), 1000

  stop: ->
    @ticktack.pause()
    @ticktack.currentTime = 0
    clearTimeout @timer
    @updateCallback(@status)

  step: (timeLength, type) ->
    time = (timeLength - (new Date() - @startTime)) / 1000
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
