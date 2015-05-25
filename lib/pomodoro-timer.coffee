'''
Copyright (c) 2014 Yoshiori SHOJI

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
'''

events = require 'events'

module.exports =
class PomodoroTimer extends events.EventEmitter

  start: (text) ->
    taskLength = atom.config.get 'gpd.pomodoroLengthMinutes'
    taskTime = taskLength * 60 * 1000
    @emit 'start'
    @startTime = new Date()
    @text = text
    @timer = setInterval ( => @step(taskTime,"TASK") ), 1000

  abort: ->
<<<<<<< HEAD
    @status = "Aborted: #{@text}"
    @stop()

  finish: ->
    @status = "Finished: #{@text}"
=======
    @status = "Aborted #{@text}"
    @stop()

  finish: ->
    @status = "Finished #{@text}"
>>>>>>> 873440943d75bd0dad60da2b8ca8bdb4785b6222
    @stop()

  startRest: ->
    restLength = atom.config.get 'gpd.restLengthMinutes'
    restTime = restLength * 60 * 1000
    @status = "Rest"
    @stop()
    @startTime = new Date()
    @timer = setInterval ( => @step(restTime,"REST") ), 1000

  stop: ->
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
